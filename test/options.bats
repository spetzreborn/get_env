#!/usr/bin/env bats
# Options and safety checks in a local run.

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    repo=${HOME}/.get_env/dotfiles/dotfiles-master
    mkdir -p "${repo}/etc"
    writeConf dotfiles
    echo 'files2copy[0]="etc $HOME .bashrc"' >"${repo}/manifest"
    echo new >"${repo}/etc/.bashrc"
}

# Arg: repository
writeConf() {
    printf '%s\n' 'get_envGitServer="github.com"' 'get_envGitUser="spetzreborn"' 'get_envRepository="get_env"' \
        'get_envBranch="master"' 'gitServer="github.com"' 'gitUser="spetzreborn"' "repository=\"${1}\"" \
        'branch="master"' 'sshPort=22' 'pathToRepository="none"' "localWorkDir=\"${HOME}/.get_env\"" \
        'backupKeepRuns=""' 'reportUrl=""' >"${HOME}/get_env.conf"
}

getEnv() {
    "${BATS_TEST_DIRNAME}/../get_env" -f "$@"
}

@test "-q deploys without output" {
    run getEnv -q
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "$(cat "${HOME}/.bashrc")" = new ]
}

@test "-d -l writes the debug log to the given file" {
    run getEnv -d -l "${BATS_TEST_TMPDIR}/debug.log"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"saving debugLog to: ${BATS_TEST_TMPDIR}/debug.log"* ]]
    grep -q 'copyFiles() was called' "${BATS_TEST_TMPDIR}/debug.log"
}

@test "an unknown option is refused" {
    run getEnv -x
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Invalid option: -x"* ]]
}

@test "an option without its argument is refused" {
    run getEnv -l
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Option -l requires an argument."* ]]
}

@test "a workdir with unsafe characters is refused" {
    run getEnv -r "${BATS_TEST_TMPDIR}/a;b"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Invalid characters in path"* ]]
}

@test "a repository ending in .git uses the directory without it" {
    writeConf dotfiles.git
    run getEnv
    [ "${status}" -eq 0 ]
    [ "$(cat "${HOME}/.bashrc")" = new ]
}
