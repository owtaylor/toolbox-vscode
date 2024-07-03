#!/bin/bash

if [ "$1" == "exec" ] ; then
    # Remove 'exec' from $@
    shift
    # We want to match toolbox in what variables from the host pass into the container
    # https://github.com/containers/toolbox/blob/master/src/pkg/utils/utils.go#L67-L90
    # We omit: COLORTERM, TERM, VTE_VERSION
    # shellcheck disable=SC1004,SC2016
    script='
        envargs=()
        for var in \
            DBUS_{SESSION,SYSTEM}_BUS_ADDRESS \
            DESKTOP_SESSION \
            DISPLAY \
            LANG \
            SHELL \
            SSH_AUTH_SOCK \
            USER \
            WAYLAND_DISPLAY \
            XAUTHORITY \
            XDG_{CURRENT_DESKTOP,DATA_DIRS,MENU_PREFIX,RUNTIME_DIR,SEAT,VTNR} \
            XDG_SESSION_{DESKTOP,ID,TYPE} \
        ; do
            if [ "${!var+set}" = "set" ] ; then
                envargs+=(-e "$var=${!var}")
            fi
        done
        exec podman exec "${envargs[@]}" "$@"
    '
    exec flatpak-spawn --host bash -c "$script" - "$@"
else
    exec flatpak-spawn --host podman "$@"
fi
