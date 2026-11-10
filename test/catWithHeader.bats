#!/usr/bin/env bats

setup() {
    source "${BATS_TEST_DIRNAME}/../get_env"
    cd "${BATS_TEST_TMPDIR}"
    localWorkDir="${BATS_TEST_TMPDIR}/work"
    mkdir -p "${localWorkDir}"
    myName=get_env
    repository=dotfiles
    branch=master
    printf '%s\n' '#!/bin/bash' '# %%GET_ENV%%' 'echo hi' >infile
}

teardown() {
    rm -r "${downloadDir}"
}

@test "header without pushedFrom has no pushed line" {
    run catWithHeader infile etc/infile
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"Pushed from"* ]]
    [ "${lines[0]}" = '#!/bin/bash' ]
    [ "${lines[3]}" = '# %%GET_ENV%% Source: dotfiles (branch master): etc/infile' ]
    [ "${lines[-1]}" = 'echo hi' ]
}

@test "header with pushedFrom names the source host" {
    echo X1 >"${localWorkDir}/pushedFrom"
    run catWithHeader infile etc/infile
    [ "${lines[5]}" = '# %%GET_ENV%% Pushed from X1 with get_env -R' ]
    [ "${lines[6]}" = '# %%GET_ENV%% git revision: unknown' ]
}
