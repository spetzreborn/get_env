#!/usr/bin/env bats
# Manifest features in a local run.

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    repo=${HOME}/.get_env/dotfiles/dotfiles-master
    hostDir=${repo}/HOSTS/$(hostname)
    mkdir -p "${repo}/etc" "${hostDir}"
    printf '%s\n' 'get_envGitServer="github.com"' 'get_envGitUser="spetzreborn"' 'get_envRepository="get_env"' \
        'get_envBranch="master"' 'gitServer="github.com"' 'gitUser="spetzreborn"' 'repository="dotfiles"' \
        'branch="master"' 'sshPort=22' 'pathToRepository="none"' "localWorkDir=\"${HOME}/.get_env\"" \
        'backupKeepRuns=""' 'reportUrl=""' >"${HOME}/get_env.conf"
    echo 'files2copy[0]="etc $HOME .bashrc"' >"${repo}/manifest"
    echo common >"${repo}/etc/.bashrc"
}

getEnv() {
    # Wide, so long lines are not folded.
    COLUMNS=500 "${BATS_TEST_DIRNAME}/../get_env" -f "$@"
}

@test "a host in ignoreHosts skips the common manifest, not its own" {
    echo "ignoreHosts=\"otherhost $(hostname)\"" >>"${repo}/manifest"
    echo 'files2copy[0]="etc $HOME .hostfile"' >"${hostDir}/manifest"
    echo host >"${repo}/etc/.hostfile"
    run getEnv
    [ "${status}" -eq 0 ]
    [ ! -e "${HOME}/.bashrc" ]
    [ "$(cat "${HOME}/.hostfile")" = host ]
}

@test "the host manifest creates its dirsToCreate" {
    echo 'dirsToCreate="$HOME/hostdir/sub"' >"${hostDir}/manifest"
    run getEnv
    [ "${status}" -eq 0 ]
    [ -d "${HOME}/hostdir/sub" ]
}

@test "dirsToCreate in single quotes is refused, not created relative" {
    echo "dirsToCreate='\$HOME/x'" >>"${repo}/manifest"
    cd "${BATS_TEST_TMPDIR}"
    run getEnv
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Not an absolute path: \$HOME/x"* ]]
    [ ! -e "${BATS_TEST_TMPDIR}/\$HOME" ]
}

@test "fails on a file in the manifest that is missing in the repository" {
    echo 'files2copy[1]="etc $HOME missing"' >>"${repo}/manifest"
    run getEnv
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"File does not exists: ${repo}/etc/missing"* ]]
}

@test "dryrun does not create links" {
    echo 'files2link[0]="etc $HOME/bin tool"' >>"${repo}/manifest"
    echo tool >"${repo}/etc/tool"
    mkdir "${HOME}/bin"
    run getEnv -n
    [ "${status}" -eq 0 ]
    [ ! -e "${HOME}/bin/tool" ]
    [[ "${output}" == *"These links should have been created or changed: tool"* ]]
}

@test "ignoreHosts matches whole host names only" {
    echo "ignoreHosts=\"$(hostname)2 x$(hostname)\"" >>"${repo}/manifest"
    run getEnv
    [ "${status}" -eq 0 ]
    [ "$(cat "${HOME}/.bashrc")" = common ]
}

@test "links creates a link to a target outside the repository" {
    echo 'links[0]="$HOME/bin/python /usr/bin/python3"' >>"${repo}/manifest"
    run getEnv
    [ "${status}" -eq 0 ]
    [ "$(readlink "${HOME}/bin/python")" = /usr/bin/python3 ]
    [[ "${output}" == *"New or changed links: python"* ]]
}

@test "links allows åäö and creates a link to a missing target with a warning" {
    echo 'links[0]="$HOME/bin/mållgan $HOME/later/tool.sh"' >>"${repo}/manifest"
    run getEnv
    [ "${status}" -eq 0 ]
    [ "$(readlink "${HOME}/bin/mållgan")" = "${HOME}/later/tool.sh" ]
    [[ "${output}" == *"Target of ${HOME}/bin/mållgan does not exist: ${HOME}/later/tool.sh"* ]]
}

@test "links does not warn for a relative target that exists next to the link" {
    mkdir "${HOME}/bin"
    touch "${HOME}/bin/tool.sh"
    echo 'links[0]="$HOME/bin/tool tool.sh"' >>"${repo}/manifest"
    run getEnv
    [ "${status}" -eq 0 ]
    [ "$(readlink "${HOME}/bin/tool")" = tool.sh ]
    [[ "${output}" != *"does not exist"* ]]
}

@test "links backs up a link that points elsewhere, as a link" {
    mkdir "${HOME}/bin"
    ln -s /old/target "${HOME}/bin/tool"
    echo 'links[0]="$HOME/bin/tool /usr/bin/env"' >>"${repo}/manifest"
    run getEnv
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Found link ${HOME}/bin/tool -> /old/target, making backup"* ]]
    [ "$(readlink "${HOME}/bin/tool")" = /usr/bin/env ]
    [ "$(readlink "${HOME}"/.get_env/backup/*"${HOME}/bin/tool")" = /old/target ]
}

@test "links backs up a file in the way, and a second run changes nothing" {
    mkdir "${HOME}/bin"
    echo local >"${HOME}/bin/tool"
    echo 'links[0]="$HOME/bin/tool /usr/bin/env"' >>"${repo}/manifest"
    getEnv
    [ "$(cat "${HOME}"/.get_env/backup/*"${HOME}/bin/tool")" = local ]
    run getEnv
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"Link "* ]]
}

@test "links in the host manifest wins over the common manifest" {
    echo 'links[0]="$HOME/bin/tool /common"' >>"${repo}/manifest"
    echo 'links[0]="$HOME/bin/tool /host"' >"${hostDir}/manifest"
    run getEnv
    [ "${status}" -eq 0 ]
    [ "$(readlink "${HOME}/bin/tool")" = /host ]
    [ ! -d "${HOME}/.get_env/backup" ]
}

@test "dryrun does not create links from links" {
    echo 'links[0]="$HOME/bin/tool /usr/bin/env"' >>"${repo}/manifest"
    mkdir "${HOME}/bin"
    run getEnv -n
    [ "${status}" -eq 0 ]
    [ ! -L "${HOME}/bin/tool" ]
    [[ "${output}" == *"These links should have been created or changed: tool"* ]]
}

@test "a links entry without a target is refused" {
    echo 'links[0]="$HOME/bin/tool"' >>"${repo}/manifest"
    run getEnv
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"A links entry needs a link and a target: ${HOME}/bin/tool"* ]]
}
