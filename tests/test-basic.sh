# shellcheck shell=bash

mock_basic() {
    :
}

test_basic() {
    mkdir ~/project
    cd ~/project || exit 1
    code --toolbox-verbose .

    assert_contents /logs/basic.cmd <<'EOF'
flatpak list --app --columns=application
podman inspect toolbox-vscode-test --format={{ range .Config.Env }}{{ println . }}{{ end }}
flatpak ps --columns=instance,application,pid
flatpak run com.visualstudio.code --remote attached-container+746f6f6c626f782d7673636f64652d74657374 /home/testuser/project
EOF

    assert_contents /home/testuser/.var/app/com.visualstudio.code/config/Code/User/settings.json <<'EOF'
{
  "remote.containers.dockerPath": "/home/testuser/.local/bin/podman-host"
}
EOF

    assert_contents /root/.vscode-server/data/Machine/settings.json <<'EOF'
{
  "remote.containers.copyGitConfig": false,
  "remote.containers.gitCredentialHelperConfigLocation": "none",
  "terminal.integrated.shell.linux": "/usr/sbin/capsh",
  "terminal.integrated.shellArgs.linux": [
    "--caps=",
    "--",
    "-c",
    "exec \"$@\"",
    "/bin/sh",
    "/bin/bash",
    "-l"
  ]
}
EOF

    assert_contents "/home/testuser/.var/app/com.visualstudio.code/config/Code/User/globalStorage/ms-vscode-remote.remote-containers/nameConfigs/toolbox-vscode-test.json" <<'EOF'
{
  // Support requested in https://github.com/microsoft/vscode-remote-release/issues/4053.
  // "name": "Toolbox toolbox-vscode-test",
  "remoteUser": "${localEnv:USER}",
  "remoteEnv": {
    "PATH": "/home/testuser/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  }
}
EOF
}

mock_installation() {
    if match flatpak list --app --columns=application ; then
        exit 0
    fi
}

test_installation() {
    mkdir ~/project
    cd ~/project || exit 1
    yes | code --toolbox-verbose .

    assert_contents /logs/installation.cmd <<'EOF'
flatpak list --app --columns=application
flatpak remotes --columns=name
flatpak install flathub com.visualstudio.code
podman inspect toolbox-vscode-test --format={{ range .Config.Env }}{{ println . }}{{ end }}
flatpak ps --columns=instance,application,pid
flatpak run com.visualstudio.code --remote attached-container+746f6f6c626f782d7673636f64652d74657374 /home/testuser/project
EOF
}

mock_running() {
    if match flatpak ps --columns=instance,application,pid ; then
        # Stray leftover
        echo "424242 com.visualstudio.code 999"
        # Child
        echo "654321 com.visualstudio.code 234"
        # Host - the way we want
        echo "123456 com.visualstudio.code 123"
        exit 0
    fi
}

test_running() {
    export TOOLBOX_VSCODE_FAKE_PROC=$HOME/proc

    mkdir -p ~/proc/234
    mkdir -p ~/proc/123
    echo -ne 'bwrap\0--args\000042\0/app/bin/zypak-helper\0child\0' > ~/proc/234/cmdline
    echo -ne 'bwrap\0--args\000040\0/app/bin/zypak-helper\0host\0' > ~/proc/123/cmdline

    mkdir ~/project
    cd ~/project || exit 1
    code --toolbox-verbose .

    assert_contents /logs/running.cmd <<'EOF'
flatpak list --app --columns=application
podman inspect toolbox-vscode-test --format={{ range .Config.Env }}{{ println . }}{{ end }}
flatpak ps --columns=instance,application,pid
flatpak enter 123456 sh -c 
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
     /home/testuser/project /home/testuser /app/extra/vscode/code /app/extra/vscode/resources/app/out/cli.js --extensions-dir=/home/testuser/.var/app/com.visualstudio.code/data/vscode/extensions --remote attached-container+746f6f6c626f782d7673636f64652d74657374 /home/testuser/project
EOF
}
