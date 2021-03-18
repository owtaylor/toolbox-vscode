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
podman inspect toolbox-vscode-test --format={{ range .Config.Env }}{{ . }}{{"\n"}}{{ end }}
flatpak ps --columns=instance,application
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
    "COLORTERM": "${localEnv:COLORTERM}",
    "DBUS_SESSION_BUS_ADDRESS": "${localEnv:DBUS_SESSION_BUS_ADDRESS}",
    "DESKTOP_SESSION": "${localEnv:DESKTOP_SESSION}",
    "LANG": "${localEnv:LANG}",
    "PATH": "/home/testuser/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    "TERM": "${localEnv:TERM}",
    "XDG_CURRENT_DESKTOP": "${localEnv:XDG_CURRENT_DESKTOP}",
    "XDG_DATA_DIRS": "${localEnv:XDG_DATA_DIRS}",
    "XDG_MENU_PREFIX": "${localEnv:XDG_MENU_PREFIX}",
    "XDG_RUNTIME_DIR": "${localEnv:XDG_RUNTIME_DIR}",
    "XDG_SESSION_DESKTOP": "${localEnv:XDG_SESSION_DESKTOP}",
    "XDG_SESSION_TYPE": "${localEnv:XDG_SESSION_TYPE}"
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
podman inspect toolbox-vscode-test --format={{ range .Config.Env }}{{ . }}{{"\n"}}{{ end }}
flatpak ps --columns=instance,application
flatpak run com.visualstudio.code --remote attached-container+746f6f6c626f782d7673636f64652d74657374 /home/testuser/project
EOF
}

mock_running() {
    if match flatpak ps --columns=instance,application ; then
        echo "123456 com.visualstudio.code"
        exit 0
    fi
}

test_running() {
    mkdir ~/project
    cd ~/project || exit 1
    code --toolbox-verbose .

    assert_contents /logs/running.cmd <<'EOF'
flatpak list --app --columns=application
podman inspect toolbox-vscode-test --format={{ range .Config.Env }}{{ . }}{{"\n"}}{{ end }}
flatpak ps --columns=instance,application
flatpak enter 123456 sh -c 
        cd $0
        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID/bus \
        DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket \
            exec "$@"
     /home/testuser/project code --remote attached-container+746f6f6c626f782d7673636f64652d74657374 /home/testuser/project
EOF
}
