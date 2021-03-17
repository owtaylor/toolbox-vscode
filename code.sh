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
            echo -e "\033[1m\033[34mtoolbox-vscode\033[0m: $@" 1>&2
        fi
    }
    info() {
        echo -e "\033[1m\033[34mtoolbox-vscode\033[0m: \033[1m$@\033[0m" 1>&2
    }
else
    verbose() {
        if $verbose ; then
            echo -e "toolbox-vscode: $@" 1>&2
        fi
    }
    info() {
        echo -e "toolbox-vscode: $@" 1>&2
    }
fi

path_remove() {
    # remove the argument from $PATH
    local -a path newpath

    SAVEIFS=$IFS
    IFS=:
    read -a path <<<$PATH

    newpath=()
    for p in "${path[@]}" ; do
        if [[ "$p" != "$1" ]] ; then
            newpath+=($p)
        fi
    done

    PATH="${newpath[*]}"
    IFS=$SAFEIFS
}

### Argument parsing

args=("$@")
arg_index=0
new_args=()

next_arg() {
    arg_index=$(($arg_index + 1))
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
container_name="$(. /run/.containerenv && echo $name)"
container_name_encoded=$(echo -n $container_name | od -t x1 -A none -v | tr -d ' \n')

### Make sure that we have the Visual Studio Code Flatpak installed

verbose "Checking if Visual Studio Code Flatpak is installed"

if $flatpak list --app --columns=application | grep -q com.visualstudio.code ; then
    verbose "Visual Studio Code Flatpak is installed"
else
    read -p "Visual Studio Code Flatpak is not installed. Install? (y/N) " install
    case "$install" in
        y|Y)
            if ! $flatpak remotes --columns=name | grep -q '^flathub$' ; then
                echo "No flathub remote to install from, see https://flathub.org/" 1>&2
                exit 1
            fi
            $flatpak install flathub com.visualstudio.code
            if [ "$?" != 0 ] ; then
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
if [ ! -f $podman_wrapper ] ; then
    info "Creating wrapper script: $podman_wrapper"

    cat > $podman_wrapper <<'EOF'
#!/bin/bash
exec flatpak-spawn --host podman "$@"
EOF
fi
    chmod a+x $podman_wrapper

settings_json="$HOME/.var/app/com.visualstudio.code/config/Code/User/settings.json"

if [ ! -f $settings_json ] ; then
    info "Creating $settings_json"

    mkdir -p $(dirname $settings_json)
    cat > $settings_json <<EOF
{
  "remote.containers.dockerPath": "$podman_wrapper"
}
EOF
elif ! grep -q remote.containers.dockerPath $settings_json ; then
    # Assume that if remote.containers.dockerPath is set, its set to something that works
    info "Editing $settings_json to set remote.containers.dockerPath"
    sed -i '1s@{@{\n  "remote.containers.dockerPath": "'$podman_wrapper'",@' $settings_json
fi

### Make sure that we have a writeable-by-user /root/.vscode-server directory

# this is where vscode stores per-container data/settings
if [ ! -w /root/.vscode-server ] ; then
    info "Creating /root/.vscode-server"
    sudo chmod a+x /root
    sudo mkdir -p /root/.vscode-server
    sudo chown $UID:$(id -g) /root/.vscode-server
fi

### Make sure we have a visual-studio code configuration for this container

name_config="$HOME/.var/app/com.visualstudio.code/config/Code/User/globalStorage/ms-vscode-remote.remote-containers/nameConfigs/$container_name.json"
if $toolbox_reset_configuration || [ ! -f $name_config ] ; then
    # The reason for including $PATH in removeEnv is so that any path modifications
    # set up in ~/.bashrc / ~/.bash_profile are present in the environment where
    # vscode runs commands, not just in the interactive terminal. As a special case
    # we remove any Python virtualenv path, in case this script is being invoked
    # within a virtual env.
    if [ -n "$VIRTUAL_ENV" ] ; then
        path_remove "$VIRTUAL_ENV/bin"
    fi

    info "Creating configuration for $container_name"
    mkdir -p "$(dirname $name_config)"
    cat > $name_config <<EOF
{
  // Support requested in https://github.com/microsoft/vscode-remote-release/issues/4053.
  // "name": "Toolbox $container_name",
  "remoteUser": "\${localEnv:USER}",
  "remoteEnv": {
    "COLORTERM": "\${localEnv:COLORTERM}",
    "DBUS_SESSION_BUS_ADDRESS": "\${localEnv:DBUS_SESSION_BUS_ADDRESS}",
    "DESKTOP_SESSION": "\${localEnv:DESKTOP_SESSION}",
    // This is whatever it was when the config was created
    "DISPLAY": "$DISPLAY",
    "LANG": "\${localEnv:LANG}",
    "PATH": "$path",
    "SHELL": "$SHELL",
    "SSH_AUTH_SOCK": "$SSH_AUTH_SOCK",
    "TERM": "\${localEnv:TERM}",
    "XDG_CURRENT_DESKTOP": "\${localEnv:XDG_CURRENT_DESKTOP}",
    "XDG_DATA_DIRS": "\${localEnv:XDG_DATA_DIRS}",
    "XDG_MENU_PREFIX": "\${localEnv:XDG_MENU_PREFIX}",
    "XDG_RUNTIME_DIR": "\${localEnv:XDG_RUNTIME_DIR}",
    "XDG_SESSION_DESKTOP": "\${localEnv:XDG_SESSION_DESKTOP}",
    "XDG_SESSION_TYPE": "\${localEnv:XDG_SESSION_TYPE}"
  }
}
EOF
fi

### Make sure that we have an appropriate settings.json in the container

# There's a settings key in the attached-container configuration file, documented
# as "Adds default settings.json values into a container/machine specific settings file",
# but if the user adds any settings for the container, the settings-key in the
# attached-container configuration file is overwritten without merging.

settings="/root/.vscode-server/data/Machine/settings.json"
if $toolbox_reset_configuration || [ ! -f $settings ] ; then
    info "Creating $settings"

    mkdir -p "$(dirname $settings)"
    cat > $settings <<EOF
{
  "remote.containers.copyGitConfig": false,
  "remote.containers.gitCredentialHelperConfigLocation": "none",
  "terminal.integrated.shell.linux": "/usr/sbin/capsh",
  "terminal.integrated.shellArgs.linux": [
    "--caps=",
    "--",
    "-c",
    "exec \"\$@\"",
    "/bin/sh",
    "$SHELL",
    "-l"
  ]
}
EOF
fi

# Different invocations of the Flatpak have separate $XDG_DATA_DIR;
# to actually open a window in the existing process requires
# hackery.

# https://github.com/flathub/com.visualstudio.code/issues/210

verbose "Checking for running Visual Studio Code Flatpak"
existing=$($flatpak ps --columns=instance,application | sort -nr | while read instance application  ; do
   if [ "$application" == "com.visualstudio.code" ] ; then
       echo "$instance"
       break
   fi
done)

if [ "$existing" = "" ] ; then
    verbose "No running Visual Studio Code Flatpak, will use 'flatpak run'"
    $verbose && set -x
    $flatpak run com.visualstudio.code \
             --remote attached-container+$container_name_encoded "${new_args[@]}"
else
    verbose "Found running Visual Studio Code Flatpak, will use 'flatpak enter'"
    $verbose && set -x
    $flatpak enter $existing sh -c 'cd $0; DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID/bus DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket exec "$@"' "$PWD" code \
             --remote attached-container+$container_name_encoded "${new_args[@]}"
fi
