#!/bin/bash

sourcedir="$(dirname "$0")"
testsdir="$sourcedir/tests"
logdir="$sourcedir/logs"

build=false
args=()
while [[ $# -gt 0 ]] ; do
    if [[ $1 = "--build" ]] ; then
        build=true
    else
        args+=("$1")
    fi
    shift
done

if $build || ! podman image inspect toolbox-vscode-test  >/dev/null 2>&1 ; then
    podman build \
        -t toolbox-vscode-test \
        --build-arg=uid=$UID --build-arg=gid="$(id -g)" \
        "$testsdir/framework"
fi

[ -d "$logdir" ] || mkdir "$logdir"

# Propagate terminal status to innner script
t=
if [ -t 1 ] ; then
    t=-t
fi

# --privileged is needed so that /run/.containerenv is created
podman run $t --rm \
        --name=toolbox-vscode-test \
        --privileged --userns=keep-id \
        -v "$sourcedir":/source -v "$logdir":/logs \
        toolbox-vscode-test \
        /source/tests/framework/run-tests-inside.sh "${args[@]}"
