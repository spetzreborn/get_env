#!/usr/bin/env bats

setup() {
    source "${BATS_TEST_DIRNAME}/../get_env"
    cd "${BATS_TEST_TMPDIR}"
    mkdir -p repo/etc repo/HOSTS/myhost/conf repo/HOSTS/otherhost
    echo 'files2copy[0]="etc $HOME .bashrc"' >repo/manifest
    echo 'files2copy[0]="/HOSTS/myhost/conf/ $HOME .xprofile"' >repo/HOSTS/myhost/manifest
    echo 'files2copy[0]="etc $HOME secret"' >repo/HOSTS/otherhost/manifest
    touch repo/etc/.bashrc repo/etc/secret repo/HOSTS/myhost/conf/.xprofile repo/unrelated
}

teardown() {
    rm -r "${downloadDir}"
}

@test "host without HOSTS directory gets only the common manifest" {
    bundleRepository repo somehost bundle.tgz
    run tar -t -z -f bundle.tgz
    [ "${output}" = $'etc/.bashrc\nmanifest' ]
}

@test "host with HOSTS directory also gets its own manifest and files" {
    bundleRepository repo myhost bundle.tgz
    run tar -t -z -f bundle.tgz
    [ "${output}" = $'HOSTS/myhost/conf/.xprofile\nHOSTS/myhost/manifest\netc/.bashrc\nmanifest' ]
}

@test "fails when a referenced file is missing" {
    rm repo/etc/.bashrc
    run bundleRepository repo somehost bundle.tgz
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"not found"*"etc/.bashrc"* ]]
    [ ! -e bundle.tgz ]
}

@test "fails on a manifest that does not validate" {
    echo 'touch /tmp/pwned' >>repo/HOSTS/myhost/manifest
    run bundleRepository repo myhost bundle.tgz
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"contains bad things"* ]]
    [ ! -e bundle.tgz ]
}
