#!/usr/bin/env bats
# Manifest features in a local run.

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    repo=${HOME}/.get_env/dotfiles/dotfiles-master
    hostDir=${repo}/HOSTS/$(hostname)
    mkdir -p "${repo}/etc" "${hostDir}"
    printf '%s\n' 'get_envGitServer="github.com"' 'get_envGitUser="spetzreborn"' 'get_envRepository="get_env"' \
        'get_envBranch="master"' 'gitServer="github.com"' 'gitUser="spetzreborn"' 'repository="dotfiles"' \
        'branch="master"' 'sshPort=22' 'pathToRepository="none"' "localWorkDir=\"${HOME}/.get_env\"" \
        'backupKeepRuns=""' 'reportUrl=""' >"${HOME}/get_env.conf"
    echo 'files2copy[0]="etc $HOME .bashrc"' >"${repo}/manifest"
    echo common >"${repo}/etc/.bashrc"
}

getEnv() {
    "${BATS_TEST_DIRNAME}/../get_env" -f "$@"
}

@test "a host in ignoreHosts skips the common manifest, not its own" {
    echo "ignoreHosts=\"otherhost $(hostname)\"" >>"${repo}/manifest"
    echo 'files2copy[0]="etc $HOME .hostfile"' >"${hostDir}/manifest"
    echo host >"${repo}/etc/.hostfile"
    run getEnv
    [ "${status}" -eq 0 ]
    [ ! -e "${HOME}/.bashrc" ]
    [ "$(cat "${HOME}/.hostfile")" = host ]
}

@test "the host manifest creates its dirsToCreate" {
    echo 'dirsToCreate="$HOME/hostdir/sub"' >"${hostDir}/manifest"
    run getEnv
    [ "${status}" -eq 0 ]
    [ -d "${HOME}/hostdir/sub" ]
}

@test "dirsToCreate in single quotes is refused, not created relative" {
    echo "dirsToCreate='\$HOME/x'" >>"${repo}/manifest"
    cd "${BATS_TEST_TMPDIR}"
    run getEnv
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Not an absolute path: \$HOME/x"* ]]
    [ ! -e "${BATS_TEST_TMPDIR}/\$HOME" ]
}

@test "fails on a file in the manifest that is missing in the repository" {
    echo 'files2copy[1]="etc $HOME missing"' >>"${repo}/manifest"
    run getEnv
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"File does not exists: ${repo}/etc/missing"* ]]
}
