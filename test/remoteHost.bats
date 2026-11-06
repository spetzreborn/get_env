#!/usr/bin/env bats
# get_env -R end to end, with an ssh stub that runs the command in another home directory.

setup() {
    T=${BATS_TEST_TMPDIR}
    LOCAL_HOME=${T}/local
    export REMOTE_HOME=${T}/remote
    repo=${LOCAL_HOME}/.get_env/dotfiles/dotfiles-master
    mkdir -p "${T}/bin" "${REMOTE_HOME}" "${repo}/etc" "${repo}/HOSTS/$(hostname)" "${repo}/HOSTS/otherhost"

    printf '%s\n' '#!/bin/bash' 'shift' 'cd "${REMOTE_HOME}" && HOME="${REMOTE_HOME}" exec bash -c "$*"' >"${T}/bin/ssh"
    chmod +x "${T}/bin/ssh"

    printf '%s\n' 'get_envGitServer="github.com"' 'get_envGitUser="spetzreborn"' 'get_envRepository="get_env"' \
        'get_envBranch="master"' 'gitServer="github.com"' 'gitUser="spetzreborn"' 'repository="dotfiles"' \
        'branch="master"' 'sshPort=22' 'pathToRepository="none"' "localWorkDir=\"${LOCAL_HOME}/.get_env\"" \
        'backupKeepRuns=""' 'reportUrl=""' >"${LOCAL_HOME}/get_env.conf"

    printf '%s\n' 'files2copy[0]="etc $HOME .bashrc"' 'dirsToCreate="$HOME/.ssh/tmp"' >"${repo}/manifest"
    echo "files2copy[0]=\"/HOSTS/$(hostname)/ \$HOME .hostfile\"" >"${repo}/HOSTS/$(hostname)/manifest"
    echo 'files2copy[0]="etc $HOME secret"' >"${repo}/HOSTS/otherhost/manifest"
    printf '%s\n' '# %%GET_ENV%%' 'alias ll="ls -l"' >"${repo}/etc/.bashrc"
    echo host >"${repo}/HOSTS/$(hostname)/.hostfile"
    echo secret >"${repo}/etc/secret"
}

getEnv() {
    HOME=${LOCAL_HOME} PATH="${T}/bin:${PATH}" "${BATS_TEST_DIRNAME}/../get_env" -f "$@"
}

@test "deploys the files of the common and host manifest to the remote host" {
    run getEnv -R target
    [ "${status}" -eq 0 ]
    grep -q '^alias ll' "${REMOTE_HOME}/.bashrc"
    grep -q "Pushed from ${HOSTNAME} with get_env -R" "${REMOTE_HOME}/.bashrc"
    [ "$(cat "${REMOTE_HOME}/.hostfile")" = host ]
    [ -d "${REMOTE_HOME}/.ssh/tmp" ]
}

@test "sends only the files the remote host needs" {
    getEnv -R target
    remoteRepo=${REMOTE_HOME}/.get_env/dotfiles/dotfiles-master
    [ -f "${remoteRepo}/etc/.bashrc" ]
    [ ! -e "${remoteRepo}/etc/secret" ]
    [ ! -e "${remoteRepo}/HOSTS/otherhost" ]
    [ ! -e "${remoteRepo}.new" ]
}

@test "does not deploy on the local host" {
    getEnv -R target
    [ ! -e "${LOCAL_HOME}/.bashrc" ]
    [ ! -e "${LOCAL_HOME}/.hostfile" ]
}

@test "second push changes nothing" {
    getEnv -R target
    run getEnv -R target
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"Copy new"* ]]
    [ ! -e "${REMOTE_HOME}/.get_env/backup" ]
}

@test "dryrun does not change files on the remote host" {
    getEnv -R target
    echo 'alias la="ls -a"' >>"${repo}/etc/.bashrc"
    run getEnv -n -R target
    [ "${status}" -eq 0 ]
    ! grep -q 'alias la' "${REMOTE_HOME}/.bashrc"
}

@test "a file removed from the manifest is removed from the remote copy" {
    getEnv -R target
    echo 'files2copy[0]="/ $HOME .profile"' >"${repo}/HOSTS/$(hostname)/manifest"
    touch "${repo}/.profile"
    getEnv -R target
    [ ! -e "${REMOTE_HOME}/.get_env/dotfiles/dotfiles-master/HOSTS/$(hostname)/.hostfile" ]
    [ -f "${REMOTE_HOME}/.profile" ]
}

@test "fails before sending when a manifest file is missing" {
    echo 'files2copy[1]="etc $HOME missing"' >>"${repo}/manifest"
    run getEnv -R target
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"not found"*"etc/missing"* ]]
    [ ! -e "${REMOTE_HOME}/.get_env" ]
}

@test "fails when get_env fails on the remote host" {
    touch "${REMOTE_HOME}/.ssh"
    run getEnv -R target
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"get_env failed on target"* ]]
}

@test "rejects a host starting with -" {
    run getEnv -R -oProxyCommand=x
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Invalid host"* ]]
}
