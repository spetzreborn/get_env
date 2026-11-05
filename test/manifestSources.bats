#!/usr/bin/env bats

setup() {
    source "${BATS_TEST_DIRNAME}/../get_env"
    cd "${BATS_TEST_TMPDIR}"
}

teardown() {
    rm -r "${downloadDir}"
}

@test "joins fromDir and each file" {
    echo 'files2copy[0]="etc $HOME .bashrc  .vimrc"' >manifest
    run manifestSources manifest
    [ "${status}" -eq 0 ]
    [ "${output}" = $'etc/.bashrc\netc/.vimrc' ]
}

@test "strips leading and trailing slash from fromDir" {
    echo 'files2copy[0]="/HOSTS/X1/conf/ $HOME .xprofile"' >manifest
    run manifestSources manifest
    [ "${output}" = "HOSTS/X1/conf/.xprofile" ]
}

@test "fromDir / is the repository root" {
    echo 'files2copy[0]="/ $HOME .xprofile"' >manifest
    run manifestSources manifest
    [ "${output}" = ".xprofile" ]
}

@test "includes files2link" {
    printf '%s\n' 'files2copy[0]="etc $HOME .bashrc"' 'files2link[0]="bin $HOME/.local/bin deploy.sh"' >manifest
    run manifestSources manifest
    [ "${output}" = $'etc/.bashrc\nbin/deploy.sh' ]
}

@test "prints nothing for a manifest without files" {
    echo 'dirsToCreate="$HOME/sshfs"' >manifest
    run manifestSources manifest
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "does not change the variables of the caller" {
    files2copy=(keep)
    files2link=(keep)
    dirsToCreate="keep"
    ignoreHosts="keep"
    printf '%s\n' 'files2copy[0]="etc $HOME .bashrc"' 'files2link[0]="bin $HOME deploy.sh"' \
        'dirsToCreate="$HOME/sshfs"' 'ignoreHosts="host"' >manifest
    manifestSources manifest >/dev/null
    [ "${files2copy[*]}" = "keep" ]
    [ "${files2link[*]}" = "keep" ]
    [ "${dirsToCreate}" = "keep" ]
    [ "${ignoreHosts}" = "keep" ]
}
