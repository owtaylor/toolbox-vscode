#!/bin/bash

if [ "$1" == "exec" ] ; then
    # Remove 'exec' from $@
    shift
    # shellcheck disable=SC1004,SC2016
    script='
        exec podman exec \
            -e DISPLAY="$DISPLAY" \
            -e SHELL="$SHELL" \
            -e SSH_AUTH_SOCK="$SSH_AUTH_SOCK" \
        "$@"
    '
    exec flatpak-spawn --host sh -c "$script" - "$@"
else
    exec flatpak-spawn --host podman "$@"
fi
