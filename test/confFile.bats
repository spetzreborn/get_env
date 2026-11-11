#!/usr/bin/env bats
# The conf file: created on the first run, completed on a version bump, validated.

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    mkdir -p "${HOME}"
    conf="${HOME}/get_env.conf"
}

getEnv() {
    "${BATS_TEST_DIRNAME}/../get_env" -f "$@"
}

@test "the first run writes a conf and stops" {
    run getEnv
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Created ${conf}, before running get_env again, edit ${conf}"* ]]
    grep -q '^repository=' "${conf}"
    grep -q "^localWorkDir=\"${HOME}/.get_env\"" "${conf}"
}

@test "a conf missing a variable gets a .new with the old values, and stops" {
    getEnv || true
    sed -i -e 's/^repository=.*/repository="mine"/' -e '/^backupKeepRuns=/d' "${conf}"
    run getEnv
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"missing: backupKeepRuns"* ]]
    grep -q '^backupKeepRuns=' "${conf}.new"
    grep -q '^repository="mine"' "${conf}.new"
    ! grep -q '^backupKeepRuns=' "${conf}"
}

@test "a conf with a command is not run" {
    getEnv || true
    echo "touch ${BATS_TEST_TMPDIR}/ran" >>"${conf}"
    run getEnv
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"contains bad things"* ]]
    [ ! -e "${BATS_TEST_TMPDIR}/ran" ]
}
