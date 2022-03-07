#!/bin/bash
#
# toolbox-vscode: code.sh
# Copyright the toolbox-vscode authors, 2021
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

verbose=false

### Helper functions

if [ -t 2 ] ; then
    verbose() {
        if $verbose ; then
            echo -e "\033[1m\033[34mtoolbox-vscode\033[0m: $*" 1>&2
        fi
    }
    info() {
        echo -e "\033[1m\033[34mtoolbox-vscode\033[0m: \033[1m$*\033[0m" 1>&2
    }
else
    verbose() {
        if $verbose ; then
            echo -e "toolbox-vscode: $*" 1>&2
        fi
    }
    info() {
        echo -e "toolbox-vscode: $*" 1>&2
    }
fi

path_remove() {
    # remove the argument from $PATH
    local -a path newpath

    saveIFS=$IFS
    IFS=:
    read -r -a path <<<"$PATH"

    newpath=()
    for p in "${path[@]}" ; do
        if [[ "$p" != "$1" ]] ; then
            newpath+=("$p")
        fi
    done

    PATH="${newpath[*]}"
    IFS=$saveIFS
}

read_cmdline() {
    # read the command line of $2 into the array variable $1
    local PROC=${TOOLBOX_VSCODE_FAKE_PROC:-/proc}
    local -n var=$1
    [ -e "$PROC/$2/cmdline" ] || return 1

    while read -r -d '' arg ; do
        var+=("$arg")
    done < "$PROC/$2/cmdline"
    return 0
}

if [ ! -L "$0" ] ; then
    echo "$(basename "$0"): Only symlinked installation currently supported" 1>&2
    exit 1
fi

code_sh="$(readlink "$0")"
podman_host_sh="$(dirname "$code_sh")/podman-host.sh"

if [ ! -f "$podman_host_sh" ] ; then
    echo "$(basename "$0"): $0 should be a symlink to code.sh in the toolbox-vscode checkout" 1>&2
    exit 1
fi

### Argument parsing

args=("$@")
arg_index=0
new_args=()

next_arg() {
    arg_index=$((arg_index + 1))
}

copy_arg() {
    new_args+=("${args[$arg_index]}")
    next_arg
}

copy_arg_with_parameter() {
    copy_arg
    if [ "$arg_index" -lt "${#args[@]}" ] ; then
        copy_arg
    fi
}

toolbox_reset_configuration=false
# Because 'code' without any arguments opens the last workspace in the
# history, ignoring history, we add --new-window if there are no
# uris, no paths, and no --new-window/--reuse-window.
add_new_window=true
while [ "$arg_index" -lt "${#args[@]}" ] ; do
    arg="${args[$arg_index]}"
    case "$arg" in
        # Custom argument added by us
        --toolbox-reset-configuration)
            toolbox_reset_configuration=true
            next_arg
            ;;
        --toolbox-verbose)
            verbose=true
            next_arg
            ;;
        # Explicit paths passed by user
        --file-uri | \
        --folder-uri)
            add_new_window=false
            copy_arg_with_parameter
            ;;
        --file-uri=* | \
        --folder-uri=*)
            add_new_window=false
            copy_arg
            ;;
        # Other string arguments that expect another parameter - as of 2021-03-11
        --builtin-extensions-dir | \
        --category | \
        --crash-reporter-id | \
        --debugBrkPluginHost | \
        --debugBrkSearch | \
        --debugId | \
        --debugPluginHost | \
        --debugSearch | \
        --disable-extension | \
        --disableExtensions | \
        --driver | \
        --enable-proposed-api | \
        --export-default-configuration | \
        --extensionDevelopmentPath | \
        --extensionHomePath | \
        --extensionTestsPath | \
        --extensions-download-dir | \
        --force-device-scale-factor | \
        --inspect | \
        --inspect-brk | \
        --inspect-brk-extensions | \
        --inspect-brk-search | \
        --inspect-extensions | \
        --inspect-search | \
        --install-builtin-extension | \
        --install-extension | \
        --install-source | \
        --js-flags | \
        --locale | \
        --locate-extension | \
        --log | \
        --log-net-log | \
        --logsPath | \
        --max-memory | \
        --prof-append-timers | \
        --prof-startup-prefix | \
        --proxy-bypass-list | \
        --proxy-pac-url | \
        --proxy-server | \
        --remote | \
        --sync | \
        --trace-category-filter | \
        --trace-options | \
        --uninstall-extension | \
        --user-data-dir | \
        --waitMarkerFilePath)
            copy_arg_with_parameter
            ;;
        --help | \
        --new-window | \
        --reuse_window)
            add_new_window=false
            copy_arg
            ;;
        # Other arguments
        -*)
            copy_arg
            ;;
        # absolute_paths
        /*)
            add_new_window=false
            copy_arg
            ;;
        # Special case relative path .
        .)
            add_new_window=false
            new_args+=("$PWD")
            next_arg
            ;;
        # Other relative paths
        *)
            add_new_window=false
            new_args+=("$PWD/$arg")
            next_arg
            ;;
    esac
done

if $add_new_window ; then
    new_args+=("--new-window")
fi

flatpak="flatpak-spawn --host flatpak"
# shellcheck disable=SC1091,SC2154
container_name="$(. /run/.containerenv && echo "$name")"
container_name_encoded=$(echo -n "$container_name" | od -t x1 -A none -v | tr -d ' \n')

### Make sure that we have the Visual Studio Code Flatpak installed

verbose "Checking if Visual Studio Code Flatpak is installed"

if $flatpak list --app --columns=application | grep -q com.visualstudio.code ; then
    verbose "Visual Studio Code Flatpak is installed"
else
    read -r -p "Visual Studio Code Flatpak is not installed. Install? (y/N) " install
    case "$install" in
        y|Y)
            if ! $flatpak remotes --columns=name | grep -q '^flathub$' ; then
                echo "No flathub remote to install from, see https://flathub.org/" 1>&2
                exit 1
            fi
            if ! $flatpak install flathub com.visualstudio.code; then
                echo "Installation failed" 1>&2
                exit 1
            fi
            ;;
        *)
            exit 1
            ;;
    esac
fi

### Make sure that we have a podman wrapper configured

podman_wrapper="$HOME/.local/bin/podman-host"
if [ "$(readlink "$podman_wrapper")" != "$podman_host_sh" ] ; then
    info "Making $podman_wrapper a link to podman-host.sh"
    ln -sf "$podman_host_sh" "$podman_wrapper"
fi


settings_json="$HOME/.var/app/com.visualstudio.code/config/Code/User/settings.json"

# Here's where we edit a JSON file with grep and sed...

# Quote regular expression characters - a " in the path would still mess us up
wrapper_quoted="$(echo "$podman_wrapper" |  sed -r 's@([$.*[\\^])@\\\1@g')"

if [ ! -f "$settings_json" ] ; then
    info "Creating $settings_json"

    mkdir -p "$(dirname "$settings_json")"
    cat > "$settings_json" <<EOF
{
  "remote.containers.dockerPath": "$podman_wrapper"
}
EOF
elif ! grep -q '"remote\.containers\.dockerPath": *"'"$wrapper_quoted"'"' "$settings_json" ; then
    if ! grep -q '"remote\.containers\.dockerPath"' "$settings_json" ; then
        info "Editing $settings_json to add remote.containers.dockerPath"
        sed -i '1s@{@{\n    "remote.containers.dockerPath": "'"$podman_wrapper"'",@' \
            "$settings_json"
    else
        info "Editing $settings_json to update remote.containers.dockerPath"
        sed -i -r 's@("remote.containers.dockerPath": *")[^"]*@\1'"$podman_wrapper"'@' \
            "$settings_json"
    fi
fi

### See where VSCode is going to write machine specific config/data

# VSCode puts its .vscode-server directory in the value of $HOME
# determined by 'podman inspect <container>'. For toolboxes, three
# values have been seen, depending on podman version.
#
#  /root
#  /
#  User's homedir
#
# The first two are OK - we just need to make them world-writable,
# but for the third, we need ot create a symlink to avoid having
# different toolboxes step on each other.

homevar="$(flatpak-spawn --host podman inspect "$container_name" \
    --format='{{ range .Config.Env }}{{ println . }}{{ end }}' \
    | grep ^HOME=)"
homevar="${homevar#HOME=}"

case $homevar in
    /)
        vscode_server="/.vscode-server"
        ;;
    /root)
        vscode_server="/root/.vscode-server"
        ;;
    "$HOME")
        vscode_server="/.vscode-server"

        if [ -e "$HOME/.vscode-server" ] && [ ! -L "$HOME/.vscode-server" ] ; then
            echo "$HOME/.vscode-server is not a symlink - this is probably a left-over." 1>&2
            echo "Please delete this directory and re-run." 1>&2
            exit 1
        fi
        if [ "$(readlink "$HOME/.vscode-server")" != $vscode_server ] ; then
            info "Creating symlink from $HOME/.vscode-server to /.vscode-server"
            ln -T -sf $vscode_server "$HOME/.vscode-server"
        fi
    ;;
    *)
        echo "\$HOME in container config is: '$homevar' - don't know how to handle this." 1>&2
        exit 1
    ;;
esac

### Make sure that we have a writeable-by-user .vscode-server directory

if [ ! -w $vscode_server ] ; then
    info "Creating $vscode_server"
    if [ $vscode_server = /root/.vscode-server ] ; then
        sudo chmod a+x /root
    fi
    sudo mkdir -p $vscode_server
    sudo chown $UID:"$(id -g)" $vscode_server
fi

### Make sure we have a visual-studio code configuration for this container

global_storage="$HOME/.var/app/com.visualstudio.code/config/Code/User/globalStorage"
name_config="$global_storage/ms-vscode-remote.remote-containers/nameConfigs/$container_name.json"
if $toolbox_reset_configuration || [ ! -f "$name_config" ] ; then
    # The reason for including $PATH in remoteEnv is so that any path modifications
    # set up in ~/.bashrc / ~/.bash_profile are present in the environment where
    # vscode runs commands, not just in the interactive terminal. As a special case
    # we remove any Python virtualenv path, in case this script is being invoked
    # within a virtual env.
    if [ -n "$VIRTUAL_ENV" ] ; then
        path_remove "$VIRTUAL_ENV/bin"
    fi

    info "Creating configuration for $container_name"
    mkdir -p "$(dirname "$name_config")"
    cat > "$name_config" <<EOF
{
  // Support requested in https://github.com/microsoft/vscode-remote-release/issues/4053.
  // "name": "Toolbox $container_name",
  "remoteUser": "\${localEnv:USER}",
  "remoteEnv": {
    "PATH": "$PATH"
  }
}
EOF
fi

### Make sure that we have an appropriate settings.json in the container

# There's a settings key in the attached-container configuration file, documented
# as "Adds default settings.json values into a container/machine specific settings file",
# but if the user adds any settings for the container, the settings-key in the
# attached-container configuration file is overwritten without merging.

settings="$vscode_server/data/Machine/settings.json"
if $toolbox_reset_configuration || [ ! -f $settings ] ; then
    info "Creating $settings"

    mkdir -p "$(dirname $settings)"
    cat > $settings <<EOF
{
  "remote.containers.copyGitConfig": false,
  "remote.containers.gitCredentialHelperConfigLocation": "none",
  "terminal.integrated.defaultProfile.linux": "toolbox",
  "terminal.integrated.profiles.linux": {
    "toolbox": {
      "path": "/usr/sbin/capsh",
      "args": [
        "--caps=",
        "--",
        "-c",
        "exec \"\$@\"",
        "/bin/sh",
        "$SHELL",
        "-l"
      ]
    }
  }
}
EOF
fi

# If there is already a Visual Studio code process running, we want
# to open a window in that. Before Flatpak 1.11 different invocations
# of the Flatpak had a separate $XDG_DATA_DIR so the communication
# socket wasn't shared. We work around this by trying to find an
# existing Flatpak instance and executing vscode in there, so it
# will talk over the communication socket and exit. The zypak
# wrapper makes this complicated in various ways.
#
# This complex solution isn't really necessary for 1.11 and newer,
# but does make it about a second faster to put up a new window.
# If it turns out to be unreliable we'll just drop this and always
# use flatpak-run.
#
# See https://github.com/flathub/com.visualstudio.code/issues/210

verbose "Checking for running Visual Studio Code Flatpak"
existing=$($flatpak ps --columns=instance,application,pid | sort -nr | \
    # We need to find the "host" zypak process, not the client one
    # that is used to spawn sandboxes
    while read -r instance application pid ; do
        if [[ $application == "com.visualstudio.code" ]] ; then
            cmd=()
            if read_cmdline cmd "$pid" ; then
                if [[ ${cmd[0]} = bwrap && \
                    ${cmd[3]} = /app/bin/zypak-helper &&
                    ${cmd[4]} = host ]]  ; then
                    echo "$instance"
                    break
                fi
            fi
        fi
    done)

if [ "$existing" = "" ] ; then
    verbose "No running Visual Studio Code Flatpak, will use 'flatpak run'"
    $verbose && set -x
    $flatpak run com.visualstudio.code \
             --remote attached-container+"$container_name_encoded" "${new_args[@]}"
else
    verbose "Found running Visual Studio Code Flatpak, will use 'flatpak enter'"
    # flatpak enter tries to read the environment from the running process,
    # which doesn't work with the zypak wrapper, so we need to set up a basic
    # environment ourselves.
    # shellcheck disable=SC1004,SC2016
    script='
        cd $0
        HOME=$1
        shift
        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID/bus
        DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
        XDG_DATA_HOME="$HOME/.var/app/com.visualstudio.code/data"
        XDG_CONFIG_HOME="$HOME/.var/app/com.visualstudio.code/config"
        XDG_CACHE_HOME="$HOME/.var/app/com.visualstudio.code/cache"
        export HOME DBUS_SESSION_BUS_ADDRESS DBUS_SYSTEM_BUS_ADDRESS \
            XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME
        ELECTRON_RUN_AS_NODE=1 \
        PATH="${PATH}:$XDG_CONFIG_HOME/node_modules/bin" \
            exec "$@"
    '
    $verbose && set -x
    $flatpak enter "$existing" sh -c "$script" "$PWD" "$HOME" \
            /app/extra/vscode/code /app/extra/vscode/resources/app/out/cli.js \
             --ms-enable-electron-run-as-node \
            --extensions-dir="$HOME/.var/app/com.visualstudio.code/data/vscode/extensions" \
             --remote attached-container+"$container_name_encoded" "${new_args[@]}"
fi
