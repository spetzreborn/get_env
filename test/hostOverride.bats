#!/usr/bin/env bats
# A file in the host manifest replaces the same file in the common manifest.

setup() {
    T=${BATS_TEST_TMPDIR}
    export HOME=${T}/home
    repo=${HOME}/.get_env/dotfiles/dotfiles-master
    hostDir=${repo}/HOSTS/$(hostname)
    mkdir -p "${repo}/etc" "${hostDir}"

    printf '%s\n' 'get_envGitServer="github.com"' 'get_envGitUser="spetzreborn"' 'get_envRepository="get_env"' \
        'get_envBranch="master"' 'gitServer="github.com"' 'gitUser="spetzreborn"' 'repository="dotfiles"' \
        'branch="master"' 'sshPort=22' 'pathToRepository="none"' "localWorkDir=\"${HOME}/.get_env\"" \
        'backupKeepRuns=""' 'reportUrl=""' >"${HOME}/get_env.conf"

    printf '%s\n' 'files2copy[0]="etc $HOME .gitconfig .bashrc"' 'files2link[0]="etc $HOME/bin tool"' >"${repo}/manifest"
    printf '%s\n' 'files2copy[0]="/HOSTS/'"$(hostname)"' $HOME/ .gitconfig"' \
        'files2link[0]="/HOSTS/'"$(hostname)"' $HOME/bin tool"' >"${hostDir}/manifest"
    echo common >"${repo}/etc/.gitconfig"
    echo common >"${repo}/etc/.bashrc"
    echo common >"${repo}/etc/tool"
    echo host >"${hostDir}/.gitconfig"
    echo host >"${hostDir}/tool"
}

@test "the host version is put on disk, the common version is skipped" {
    run "${BATS_TEST_DIRNAME}/../get_env" -f
    [ "${status}" -eq 0 ]
    [ "$(cat "${HOME}/.gitconfig")" = host ]
    [ "$(cat "${HOME}/.bashrc")" = common ]
    [ "$(cat "${HOME}/bin/tool")" = host ]
    [ ! -d "${HOME}/.get_env/backup" ]
}

@test "second run changes nothing" {
    "${BATS_TEST_DIRNAME}/../get_env" -f
    run "${BATS_TEST_DIRNAME}/../get_env" -f
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"Copy new"* ]]
    [[ "${output}" != *"Link "* ]]
    [ ! -d "${HOME}/.get_env/backup" ]
}
