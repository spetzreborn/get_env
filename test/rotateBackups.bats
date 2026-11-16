#!/usr/bin/env bats

setup() {
    source "${BATS_TEST_DIRNAME}/../get_env"
    cd "${BATS_TEST_TMPDIR}"
    localWorkDir="${BATS_TEST_TMPDIR}/work"
    backups="${localWorkDir}/backup"
    # Run directories are named after a sortable timestamp.
    for run in 2026-01-01T10-00-00 2026-01-02T10-00-00 2026-01-03T10-00-00 2026-01-04T10-00-00; do
        mkdir -p "${backups}/${run}/home"
        echo "/home/.bashrc" >"${backups}/${run}/index"
    done
}

teardown() {
    rm -r "${downloadDir}"
}

@test "keeps everything when backupKeepRuns is not set" {
    backupKeepRuns=""
    run rotateBackups
    [ "${status}" -eq 0 ]
    [ "$(ls "${backups}" | wc -l)" -eq 4 ]
}

@test "removes the oldest runs beyond backupKeepRuns" {
    backupKeepRuns=2
    run rotateBackups
    [ "${status}" -eq 0 ]
    [ "$(ls "${backups}")" = $'2026-01-03T10-00-00\n2026-01-04T10-00-00' ]
}

@test "removes nothing when there are not more runs than backupKeepRuns" {
    backupKeepRuns=4
    run rotateBackups
    [ "${status}" -eq 0 ]
    [ "$(ls "${backups}" | wc -l)" -eq 4 ]
}

@test "leaves files in the backup directory alone" {
    backupKeepRuns=1
    touch "${backups}/notes"
    run rotateBackups
    [ "${status}" -eq 0 ]
    [ "$(ls "${backups}")" = $'2026-01-04T10-00-00\nnotes' ]
}

@test "does nothing without a backup directory" {
    backupKeepRuns=1
    rm -r "${backups}"
    run rotateBackups
    [ "${status}" -eq 0 ]
    [ ! -e "${backups}" ]
}

@test "an empty backup directory is not an error" {
    backupKeepRuns=0
    rm -r "${backups}"
    mkdir "${backups}"
    run rotateBackups
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"FAILED"* ]]
}
