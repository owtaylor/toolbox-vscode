# shellcheck shell=bash

mock_settings_edit_missing() {
    :
}

test_settings_edit_missing() {
    code --toolbox-verbose . 2>&1

    assert_contents /home/testuser/.var/app/com.visualstudio.code/config/Code/User/settings.json <<'EOF'
{
  "dev.containers.dockerPath": "/home/testuser/.local/bin/podman-host"
}
EOF
}

mock_settings_edit_add() {
    :
}

test_settings_edit_add() {
    mkdir -p /home/testuser/.var/app/com.visualstudio.code/config/Code/User
    cat > /home/testuser/.var/app/com.visualstudio.code/config/Code/User/settings.json <<'EOF'
{
    "test": "blah"
}
EOF

    code --toolbox-verbose . 2>&1

    assert_contents /home/testuser/.var/app/com.visualstudio.code/config/Code/User/settings.json <<'EOF'
{
    "dev.containers.dockerPath": "/home/testuser/.local/bin/podman-host",
    "test": "blah"
}
EOF
}

mock_settings_edit_change() {
    :
}

test_settings_edit_change() {
    mkdir -p /home/testuser/.var/app/com.visualstudio.code/config/Code/User
    cat > /home/testuser/.var/app/com.visualstudio.code/config/Code/User/settings.json <<'EOF'
{
    "dev.containers.dockerPath": "/blah/bin/podman-host"
}
EOF

    code --toolbox-verbose . 2>&1

    assert_contents /home/testuser/.var/app/com.visualstudio.code/config/Code/User/settings.json <<'EOF'
{
    "dev.containers.dockerPath": "/home/testuser/.local/bin/podman-host"
}
EOF
}
