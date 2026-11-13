#!/usr/bin/env bats
# A host is found in HOSTS by its FQDN, its hostname or its short name, in that order.

setup() {
    source "${BATS_TEST_DIRNAME}/../get_env"
    T=${BATS_TEST_TMPDIR}
    mkdir -p "${T}/HOSTS"
}

teardown() {
    rm -r "${downloadDir}"
}

@test "adds the short names after the given names, each once" {
    [ "$(hostNames admin.dsv.su.se admin)" = "admin.dsv.su.se admin" ]
    [ "$(hostNames spetz.internetz.se spetz.internetz.se)" = "spetz.internetz.se spetz" ]
    [ "$(hostNames "" x1)" = "x1" ]
}

@test "skips invalid names" {
    [ "$(hostNames '*' 'a b' 'a;b' x1)" = "x1" ]
    [ "$(hostNames)" = "" ]
}

@test "the FQDN directory is used before the short name directory" {
    mkdir "${T}/HOSTS/admin" "${T}/HOSTS/admin.dsv.su.se"
    touch "${T}/HOSTS/admin/manifest" "${T}/HOSTS/admin.dsv.su.se/manifest"
    [ "$(hostDirName "${T}" admin.dsv.su.se admin)" = admin.dsv.su.se ]
    rm "${T}/HOSTS/admin.dsv.su.se/manifest"
    [ "$(hostDirName "${T}" admin.dsv.su.se admin)" = admin ]
}

@test "the first name when no directory exists" {
    [ "$(hostDirName "${T}" admin.dsv.su.se admin)" = admin.dsv.su.se ]
}

@test "any of the names can be ignored, whole names only" {
    ignoreHosts="pi admin"
    isIgnoredHost admin.dsv.su.se admin
    ! isIgnoredHost admin2.dsv.su.se admin2
    ignoreHosts="admin.dsv.su.se"
    isIgnoredHost admin.dsv.su.se admin
}

@test "this host uses the HOSTS directory of its FQDN" {
    export HOME=${T}/home
    repo=${HOME}/.get_env/dotfiles/dotfiles-master
    mkdir -p "${T}/bin" "${repo}/HOSTS/${HOSTNAME}" "${repo}/HOSTS/${HOSTNAME}.example.org"
    printf '%s\n' '#!/bin/bash' '[ "$1" = -f ] && echo "${HOSTNAME}.example.org" || echo "${HOSTNAME}"' >"${T}/bin/hostname"
    chmod +x "${T}/bin/hostname"
    printf '%s\n' 'get_envGitServer="github.com"' 'get_envGitUser="spetzreborn"' 'get_envRepository="get_env"' \
        'get_envBranch="master"' 'gitServer="github.com"' 'gitUser="spetzreborn"' 'repository="dotfiles"' \
        'branch="master"' 'sshPort=22' 'pathToRepository="none"' "localWorkDir=\"${HOME}/.get_env\"" \
        'backupKeepRuns=""' 'reportUrl=""' >"${HOME}/get_env.conf"
    echo 'ignoreHosts=""' >"${repo}/manifest"
    for dir in "${HOSTNAME}" "${HOSTNAME}.example.org"; do
        echo "files2copy[0]=\"/HOSTS/${dir} \$HOME .hostfile\"" >"${repo}/HOSTS/${dir}/manifest"
        echo "${dir}" >"${repo}/HOSTS/${dir}/.hostfile"
    done
    PATH="${T}/bin:${PATH}" run "${BATS_TEST_DIRNAME}/../get_env" -f
    [ "${status}" -eq 0 ]
    [ "$(cat "${HOME}/.hostfile")" = "${HOSTNAME}.example.org" ]
}
