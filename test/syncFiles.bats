#!/usr/bin/env bats

setup() {
    source "${BATS_TEST_DIRNAME}/../get_env"
    cd "${BATS_TEST_TMPDIR}"
    localWorkDir="${BATS_TEST_TMPDIR}/work"
    dest="${localWorkDir}/dotfiles/dotfiles-master"
    mkdir -p src/.git src/etc "${localWorkDir}"
    echo a >src/etc/a
    printf '%s\n' '#!/bin/bash' >src/script.sh
    chmod +x src/script.sh
    touch src/.git/HEAD
}

teardown() {
    rm -r "${downloadDir}"
}

@test "copies the files, without .git, and keeps modes" {
    run syncFiles src "${dest}"
    [ "${status}" -eq 0 ]
    [ "$(cat "${dest}/etc/a")" = a ]
    [ -x "${dest}/script.sh" ]
    [ ! -e "${dest}/.git" ]
}

@test "removes files that are gone from the source" {
    syncFiles src "${dest}"
    rm src/etc/a
    echo b >src/etc/b
    run syncFiles src "${dest}"
    [ "${status}" -eq 0 ]
    [ ! -e "${dest}/etc/a" ]
    [ "$(cat "${dest}/etc/b")" = b ]
}

@test "a link into the copy keeps working" {
    syncFiles src "${dest}"
    ln -s "${dest}/etc/a" link
    echo changed >src/etc/a
    syncFiles src "${dest}"
    [ "$(cat link)" = changed ]
}

@test "removes leftovers from an interrupted run" {
    mkdir -p "${dest}.new/stale" "${dest}.old/stale"
    run syncFiles src "${dest}"
    [ "${status}" -eq 0 ]
    [ ! -e "${dest}.new" ]
    [ ! -e "${dest}.old" ]
    [ ! -e "${dest}/stale" ]
}

@test "refuses a destination outside the workdir" {
    mkdir outside
    touch outside/keep
    run syncFiles src "${BATS_TEST_TMPDIR}/outside"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"not in ${localWorkDir}"* ]]
    [ -f outside/keep ]
}

@test "refuses the workdir itself" {
    touch "${localWorkDir}/keep"
    run syncFiles src "${localWorkDir}"
    [ "${status}" -ne 0 ]
    [ -f "${localWorkDir}/keep" ]
}

@test "refuses a destination with .." {
    mkdir outside
    touch outside/keep
    run syncFiles src "${localWorkDir}/../outside"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"path contains .."* ]]
    [ -f outside/keep ]
}

@test "fails on a missing source and keeps the copy" {
    syncFiles src "${dest}"
    run syncFiles missing "${dest}"
    [ "${status}" -ne 0 ]
    [ "$(cat "${dest}/etc/a")" = a ]
}
