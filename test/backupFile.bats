#!/usr/bin/env bats
# A file is only replaced after it is backed up.

setup() {
    source "${BATS_TEST_DIRNAME}/../get_env"
    cd "${BATS_TEST_TMPDIR}"
    localWorkDir="${BATS_TEST_TMPDIR}/work"
    repository=dotfiles
    branch=master
    mkdir -p "${localWorkDir}/dotfiles/dotfiles-master/etc" home
    echo new >"${localWorkDir}/dotfiles/dotfiles-master/etc/.bashrc"
    echo local >home/.bashrc
}

teardown() {
    chmod 600 home/.bashrc 2>/dev/null || true
    rm -rf "${downloadDir}"
}

@test "a changed file is backed up before it is replaced" {
    run copyFiles etc "${BATS_TEST_TMPDIR}/home" .bashrc
    [ "${status}" -eq 0 ]
    [ "$(cat home/.bashrc)" = new ]
    [ "$(cat "${localWorkDir}/backup/${backupTimestamp}${BATS_TEST_TMPDIR}/home/.bashrc")" = local ]
}

@test "stops and keeps the file when the backup fails" {
    [ "$(id -u)" -ne 0 ] || skip "root can read the file anyway"
    # Writable but not readable: the backup fails, replacing it would not.
    chmod 200 home/.bashrc
    run copyFiles etc "${BATS_TEST_TMPDIR}/home" .bashrc
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Could not back up ${BATS_TEST_TMPDIR}/home/.bashrc, not replacing it"* ]]
    chmod 600 home/.bashrc
    [ "$(cat home/.bashrc)" = local ]
}

@test "does not replace a file with a link when the backup fails" {
    [ "$(id -u)" -ne 0 ] || skip "root can read the file anyway"
    chmod 200 home/.bashrc
    run linkFiles etc "${BATS_TEST_TMPDIR}/home" .bashrc
    [ "${status}" -ne 0 ]
    [ ! -L home/.bashrc ]
}
