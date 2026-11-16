#!/usr/bin/env bats
# downloadAndExtract() with curl and wget stubs that serve a local tarball.

setup() {
    source "${BATS_TEST_DIRNAME}/../get_env"
    cd "${BATS_TEST_TMPDIR}"
    localWorkDir="${BATS_TEST_TMPDIR}/work"
    dest="${localWorkDir}/dotfiles/dotfiles-master"

    # Without the user's git config (hooks, templates), with a fixed identity.
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
    export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

    # A tarball like GitHub's archive download, with the commit id in its header.
    git init -q -b master src
    echo a >src/a
    git -C src add a
    git -C src commit -q -m a
    commit=$(git -C src rev-parse HEAD)
    export TARBALL="${BATS_TEST_TMPDIR}/served.tar.gz"
    git -C src archive --format=tar.gz --prefix=dotfiles-master/ -o "${TARBALL}" HEAD

    # Both stubs log the URL and copy ${TARBALL} to the output file (-o or -O).
    mkdir bin
    for tool in curl wget; do
        printf '%s\n' '#!/bin/bash' \
            'while [ $# -gt 0 ]; do case $1 in -o|-O) out=$2; shift;; http*) echo "$1" >>"${BATS_TEST_TMPDIR}/urls";; esac; shift; done' \
            '[ -z "${FAIL_DOWNLOAD}" ] && cp "${TARBALL}" "${out}"' >"bin/${tool}"
        chmod +x "bin/${tool}"
    done
    PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
    httpTool=curl
}

teardown() {
    rm -rf "${downloadDir}"
}

@test "downloads, extracts and syncs the repository" {
    run downloadAndExtract github.com spetzreborn dotfiles master
    [ "${status}" -eq 0 ]
    [ "$(cat urls)" = "https://github.com/spetzreborn/dotfiles/archive/master.tar.gz" ]
    [ "$(cat "${dest}/a")" = a ]
}

@test "saves the commit id from the tarball" {
    downloadAndExtract github.com spetzreborn dotfiles master
    [ "$(cat "${localWorkDir}/revisions/dotfiles-master")" = "${commit}" ]
}

@test "revision is unknown without a commit id in the tarball" {
    tar -c -z -f "${TARBALL}" -C src --transform 's,^\.,dotfiles-master,' .
    downloadAndExtract github.com spetzreborn dotfiles master
    [ "$(cat "${localWorkDir}/revisions/dotfiles-master")" = unknown ]
}

@test "works with wget" {
    httpTool=wget
    run downloadAndExtract github.com spetzreborn dotfiles master
    [ "${status}" -eq 0 ]
    [ "$(cat "${dest}/a")" = a ]
}

@test "fails when the download fails and keeps the old copy" {
    downloadAndExtract github.com spetzreborn dotfiles master
    export FAIL_DOWNLOAD=yes
    run downloadAndExtract github.com spetzreborn dotfiles master
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Could not download"* ]]
    [ "$(cat "${dest}/a")" = a ]
}

@test "fails on a broken tarball and keeps the old copy" {
    downloadAndExtract github.com spetzreborn dotfiles master
    echo broken >"${TARBALL}"
    run downloadAndExtract github.com spetzreborn dotfiles master
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Failed to extract"* ]]
    [ "$(cat "${dest}/a")" = a ]
}
