#!/usr/bin/env bats
# Whole runs without -f: get_env and the repository are "downloaded" by a curl stub,
# or the repository is cloned from a local git repository via url.<base>.insteadOf.

setup() {
    T=${BATS_TEST_TMPDIR}
    export HOME="${T}/home"
    mkdir -p "${HOME}" "${T}/bin" "${T}/served"
    # The installed get_env, and the same version for download.
    cp "${BATS_TEST_DIRNAME}/../get_env" "${HOME}/get_env"
    mkdir -p "${T}/build/get_env-master" "${T}/build/dotfiles-master/etc"
    cp "${HOME}/get_env" "${T}/build/get_env-master/get_env"
    echo 'files2copy[0]="etc $HOME .bashrc"' >"${T}/build/dotfiles-master/manifest"
    echo github >"${T}/build/dotfiles-master/etc/.bashrc"
    serve get_env-master
    serve dotfiles-master

    # Logs the URL and serves ${T}/served/<repository>-<branch>.tar.gz.
    printf '%s\n' '#!/bin/bash' \
        'while [ $# -gt 0 ]; do case $1 in -o) out=$2; shift;; http*) url=$1;; esac; shift; done' \
        'echo "${url}" >>"${T}/urls"' \
        'name=${url#https://github.com/*/}; name=${name/\/archive\//-}' \
        'cp "${T}/served/${name}" "${out}"' >"${T}/bin/curl"
    chmod +x "${T}/bin/curl"
    export T PATH="${T}/bin:${PATH}"

    # Only this git config, so no hooks or templates of the user.
    export GIT_CONFIG_GLOBAL="${T}/gitconfig" GIT_CONFIG_NOSYSTEM=1
    export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
    export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
    git config --global url."${T}/remote/".insteadOf "ssh://git@server:22/repos/"

    writeConf github.com
}

# Arg: gitServer [branch]
writeConf() {
    printf '%s\n' 'get_envGitServer="github.com"' 'get_envGitUser="spetzreborn"' 'get_envRepository="get_env"' \
        'get_envBranch="master"' "gitServer=\"${1}\"" 'gitUser="git"' 'repository="dotfiles"' \
        "branch=\"${2:-master}\"" 'sshPort=22' 'pathToRepository="repos"' "localWorkDir=\"${HOME}/.get_env\"" \
        'backupKeepRuns=""' 'reportUrl=""' >"${HOME}/get_env.conf"
}

# Pack ${T}/build/<name> as ${T}/served/<name>.tar.gz
serve() {
    tar -c -z -f "${T}/served/${1}.tar.gz" -C "${T}/build" "${1}"
}

# A git repository with the branches master and dev.
gitRemote() {
    git init -q -b master "${T}/remote/dotfiles"
    cd "${T}/remote/dotfiles"
    mkdir etc
    echo 'files2copy[0]="etc $HOME .bashrc"' >manifest
    echo git-master >etc/.bashrc
    git add . && git commit -q -m master
    git checkout -q -b dev
    echo git-dev >etc/.bashrc
    git commit -q -a -m dev
    git checkout -q master
    cd "${T}"
}

@test "downloads get_env and the repository from github and deploys" {
    run "${HOME}/get_env"
    [ "${status}" -eq 0 ]
    [ "$(cat "${T}/urls")" = "https://github.com/spetzreborn/get_env/archive/master.tar.gz
https://github.com/git/dotfiles/archive/master.tar.gz" ]
    [[ "${output}" == *"Already running latest get_env"* ]]
    [ "$(cat "${HOME}/.bashrc")" = github ]
}

@test "a newer get_env replaces itself, restarts and deploys" {
    echo 'echo "newer get_env ran"' >>"${T}/build/get_env-master/get_env"
    serve get_env-master
    run "${HOME}/get_env"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Found newer get_env"* ]]
    [[ "${output}" == *"newer get_env ran"* ]]
    cmp "${HOME}/get_env" "${T}/build/get_env-master/get_env"
    [ "$(cat "${HOME}/.bashrc")" = github ]
}

@test "clones from an own git server and deploys" {
    gitRemote
    writeConf server
    run "${HOME}/get_env"
    [ "${status}" -eq 0 ]
    [ "$(cat "${HOME}/.bashrc")" = git-master ]
    [ "$(wc -l <"${T}/urls")" -eq 1 ]
}

@test "offline, the local git clone is used for another branch" {
    gitRemote
    writeConf server
    "${HOME}/get_env"
    writeConf server dev
    run "${HOME}/get_env" -f
    [ "${status}" -eq 0 ]
    [ "$(cat "${HOME}/.bashrc")" = git-dev ]
}

@test "offline without a local copy fails" {
    run "${HOME}/get_env" -f
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Offline and no local copy of dotfiles branch master"* ]]
}
