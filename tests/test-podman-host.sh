# shellcheck shell=bash

### Test podman-host <anything but exec>

mock_podman_host() {
    if match podman --version ; then
        echo "podman version 3.0.1"
        exit 0
    fi
}

test_podman_host() {
    # Sets up the podman-host symlink
    code --help

    version=$(podman-host --version) || fail "podman-host exited unsuccessfully"

    [[ $version = "podman version 3.0.1" ]] || fail "Didn't get mocked version"
}

### Test podman-host exec

mock_podman_host_exec() {
    if match sh @ ; then
        # flatpak-spawn --host sh -c "$script" - "$@"
        #
        # Where $script builds and executes a 'podman exec' command
        # line.
        #
        # To make sure that the script is generating the
        # right podman command line, we execute the script, with
        # a podman command that just logs its args

        # shellcheck disable=SC2154
        "${args[@]}"
        exit 0
    fi
}

test_podman_host_exec() {
    # Sets up the podman-host symlink
    code --help

    cat > /home/testuser/.local/bin/podman <<'EOF'
#!/bin/bash
echo podman "$*" >> "/logs/$TEST_NAME.cmd"
EOF
    chmod a+x /home/testuser/.local/bin/podman

    podman-host exec test-toolbox-vscode env || \
        fail "podman-host exited unsuccessfully"

    assert_grep \
        "podman exec -e SHELL=/bin/bash test-toolbox-vscode env" \
        /logs/podman_host_exec.cmd
}
