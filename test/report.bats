#!/usr/bin/env bats
# report(): post the status of a run to ${reportUrl}, with a curl stub.

setup() {
    source "${BATS_TEST_DIRNAME}/../get_env"
    cd "${BATS_TEST_TMPDIR}"
    mkdir bin
    # Logs "url data", fails when FAIL_POST is set.
    printf '%s\n' '#!/bin/bash' \
        'while [ $# -gt 0 ]; do case $1 in --data-raw) data=$2; shift;; http*) url=$1;; esac; shift; done' \
        'echo "${url} ${data}" >>"${BATS_TEST_TMPDIR}/posts"' \
        '[ -z "${FAIL_POST}" ]' >bin/curl
    chmod +x bin/curl
    PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
    httpTool=curl
    reportUrl="https://example.com/report"
    offline=""
    myName=get_env
    # Not set in every environment, e.g. containers.
    unset USER
    # Set by the conf in a real run.
    get_envGitServer=github.com get_envGitUser=spetzreborn get_envRepository=get_env get_envBranch=master
    gitServer=github.com gitUser=spetzreborn repository=dotfiles branch=master
    localWorkDir="${BATS_TEST_TMPDIR}/work"
}

teardown() {
    rm -rf "${downloadDir}"
}

@test "posts the status and the extra arguments" {
    newFiles=".bashrc "
    run report "error=failed"
    [ "${status}" -eq 0 ]
    [[ "$(cat posts)" == "https://example.com/report date="* ]]
    [[ "$(cat posts)" == *"&hostname=${HOSTNAME}&"* ]]
    [[ "$(cat posts)" == *"&newFiles=.bashrc &"* ]]
    [[ "$(cat posts)" == *"&error=failed&" ]]
}

@test "does not post without reportUrl or offline" {
    reportUrl=""
    report
    reportUrl="https://example.com/report"
    offline=true
    report
    [ ! -e posts ]
}

@test "a failed post is not an error" {
    export FAIL_POST=yes
    run report
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"FAILED"* ]]
}
