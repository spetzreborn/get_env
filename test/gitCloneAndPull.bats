#!/usr/bin/env bats
# gitCloneAndPull() and gitCheckoutAndSync() against a local repository: the ssh URL
# that get_env builds is rewritten to it with git's url.<base>.insteadOf.

setup() {
    source "${BATS_TEST_DIRNAME}/../get_env"
    cd "${BATS_TEST_TMPDIR}"
    T=${BATS_TEST_TMPDIR}
    localWorkDir="${T}/work"
    pathToRepository=repos
    myStartDirectory=${T}
    clone="${localWorkDir}/git/dotfiles"

    # Only this config, so no hooks or templates of the user, and a fixed identity.
    export GIT_CONFIG_GLOBAL="${T}/gitconfig" GIT_CONFIG_NOSYSTEM=1
    export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
    export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
    git config --global url."${T}/remote/".insteadOf "ssh://git@server:22/repos/"

    git init -q -b master remote/dotfiles
    echo master >remote/dotfiles/file
    git -C remote/dotfiles add file
    git -C remote/dotfiles commit -q -m master
    git -C remote/dotfiles branch dev
}

teardown() {
    rm -rf "${downloadDir}"
}

# Arg: branch content
remoteCommit() {
    git -C remote/dotfiles checkout -q "${1}"
    echo "${2}" >remote/dotfiles/file
    git -C remote/dotfiles commit -q -a -m "${2}"
}

@test "clones and syncs the branch, without .git" {
    run gitCloneAndPull server git dotfiles master 22
    [ "${status}" -eq 0 ]
    [ "$(cat "${localWorkDir}/dotfiles/dotfiles-master/file")" = master ]
    [ ! -e "${localWorkDir}/dotfiles/dotfiles-master/.git" ]
    [ "$(cat "${localWorkDir}/revisions/dotfiles-master")" = "$(git -C remote/dotfiles rev-parse master)" ]
}

@test "fetches and fast-forwards on the next run" {
    gitCloneAndPull server git dotfiles master 22
    remoteCommit master updated
    run gitCloneAndPull server git dotfiles master 22
    [ "${status}" -eq 0 ]
    [ "$(cat "${localWorkDir}/dotfiles/dotfiles-master/file")" = updated ]
    [ "$(cat "${localWorkDir}/revisions/dotfiles-master")" = "$(git -C remote/dotfiles rev-parse master)" ]
}

@test "fast-forwards a branch that is not checked out in the clone" {
    gitCloneAndPull server git dotfiles dev 22
    remoteCommit dev "dev updated"
    run gitCloneAndPull server git dotfiles dev 22
    [ "${status}" -eq 0 ]
    [ "$(cat "${localWorkDir}/dotfiles/dotfiles-dev/file")" = "dev updated" ]
}

@test "restores the branch that was checked out, and the start directory" {
    gitCloneAndPull server git dotfiles dev 22
    [ "$(git -C "${clone}" branch --show-current)" = master ]
    [ "$(pwd)" = "${T}" ]
}

@test "fails on a directory that is not a git repository" {
    mkdir -p "${clone}"
    run gitCloneAndPull server git dotfiles master 22
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"is not an git repository"* ]]
}

@test "fails on a clone of another repository" {
    mkdir -p "${clone}"
    git -C "${clone}" init -q
    git -C "${clone}" remote add origin "${T}/remote/other"
    run gitCloneAndPull server git dotfiles master 22
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Wrong repository"* ]]
}

@test "fails on a missing branch" {
    run gitCloneAndPull server git dotfiles nosuch 22
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Could not checkout branch nosuch"* ]]
}

@test "fails when the local branch has diverged" {
    gitCloneAndPull server git dotfiles master 22
    # Another file, so a plain merge would succeed and only --ff-only stops it.
    echo local >"${clone}/local"
    git -C "${clone}" add local
    git -C "${clone}" commit -q -m local
    remoteCommit master remote
    run gitCloneAndPull server git dotfiles master 22
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Could not fast-forward branch master"* ]]
}

@test "fails when the repository can't be cloned" {
    run gitCloneAndPull server git missing master 22
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Failed to clone missing"* ]]
}
