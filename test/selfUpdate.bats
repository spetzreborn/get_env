#!/usr/bin/env bats
# get_envDiffAndRestart(): replace ~/get_env with a downloaded newer version and run it.

setup() {
    source "${BATS_TEST_DIRNAME}/../get_env"
    cd "${BATS_TEST_TMPDIR}"
    export HOME="${BATS_TEST_TMPDIR}/home"
    myName=get_env
    localWorkDir="${HOME}/.get_env"
    get_envRepository=get_env
    get_envBranch=master
    downloaded="${localWorkDir}/get_env/get_env-master/get_env"
    mkdir -p "${downloaded%/*}"
    # The running version, and a newer one that prints how it was started.
    printf '%s\n' '#!/bin/bash' 'echo old' >"${HOME}/get_env"
    printf '%s\n' '#!/bin/bash' 'echo "new started with: $*"' >"${downloaded}"
    chmod +x "${HOME}/get_env" "${downloaded}"
}

@test "replaces itself with the newer version and runs it" {
    run get_envDiffAndRestart
    [ "${status}" -eq 0 ]
    cmp "${HOME}/get_env" "${downloaded}"
    [[ "${output}" == *"new started with: -r ${localWorkDir}" ]]
}

@test "passes on -q, -d with its log and -R" {
    quietMode="-q"
    debug="-d"
    debugLog="${BATS_TEST_TMPDIR}/debug.log"
    remoteHost=admin
    run get_envDiffAndRestart
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"new started with: -r ${localWorkDir} -q -d -l ${debugLog} -R admin" ]]
}

@test "-u does not replace or restart" {
    noGet_envUpdate="-u"
    run get_envDiffAndRestart
    [ "${status}" -eq 0 ]
    [ "$("${HOME}/get_env")" = old ]
    [[ "${output}" == *"Do not run newer"* ]]
    [[ "${output}" != *"started with"* ]]
}

@test "dryrun does not replace or restart" {
    dryrun="-n"
    run get_envDiffAndRestart
    [ "${status}" -eq 0 ]
    [ "$("${HOME}/get_env")" = old ]
    [[ "${output}" != *"started with"* ]]
}

@test "no restart when only comments differ" {
    printf '%s\n' '#!/bin/bash' '# a comment' 'echo old' >"${downloaded}"
    run get_envDiffAndRestart
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Already running latest get_env"* ]]
    [ "$(cat "${HOME}/get_env")" = $'#!/bin/bash\necho old' ]
}

@test "runs under the renamed name" {
    myName=my_env_tool
    cp "${HOME}/get_env" "${HOME}/my_env_tool"
    run get_envDiffAndRestart
    [ "${status}" -eq 0 ]
    cmp "${HOME}/my_env_tool" "${downloaded}"
    [ "$("${HOME}/get_env")" = old ]
    [[ "${output}" == *"new started with"* ]]
}
