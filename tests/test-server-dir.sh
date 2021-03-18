# Different versions of toolbox+podman result in different  values of the HOME
# environment variable in the container config. Since that determines the
# location where Visual Studio Code puts the '.vscode-server' directory,
# we have to handle them all.

# shellcheck shell=bash

do_mock_server_dir() {
    if match podman inspect toolbox-vscode-test \
             --format='{{ range .Config.Env }}{{ . }}{{"\n"}}{{ end }}' ; then
        echo "NAME=fedora-toolbox"
        echo "HOME=$1"
        exit 1
fi
}

### HOME=/

mock_server_dir_topdir() {
    do_mock_server_dir /
}

test_server_dir_topdir() {
    code .
    assert_grep '"remote.containers.copyGitConfig": false' \
                /.vscode-server/data/Machine/settings.json
}

### HOME=/root

mock_server_dir_root() {
    do_mock_server_dir /root
}

test_server_dir_root() {
    code .
    assert_grep '"remote.containers.copyGitConfig": false' \
                /root/.vscode-server/data/Machine/settings.json
}

### HOME=/home/testuser

check_home_symlink() {
    if [ ! -L /home/testuser/.vscode-server ] || \
           [ "$(readlink /home/testuser/.vscode-server)" != "/.vscode-server" ] ; then
        fail "Link to /.vscode/server wasn't created succesfully"
    fi
}

mock_server_dir_home() {
    do_mock_server_dir /home/testuser
}

test_server_dir_home() {
    code .
    check_home_symlink
    assert_grep '"remote.containers.copyGitConfig": false' \
                /home/testuser/.vscode-server/data/Machine/settings.json
}

### HOME=/home/testuser, symlink at ~/.vscode-server points somewhere else

mock_server_dir_home_old_symlink() {
    do_mock_server_dir /home/testuser
}

test_server_dir_home_old_symlink() {
    ln -s /bah/bah /home/testuser/.vscode-server
    code .
    check_home_symlink
    assert_grep '"remote.containers.copyGitConfig": false' \
                /home/testuser/.vscode-server/data/Machine/settings.json
}

### HOME=/home/testuser, ~/.vscode-server exists and isn't a symlink

mock_server_dir_home_old_dir() {
    do_mock_server_dir /home/testuser
}

test_server_dir_home_old_dir() {
    mkdir /home/testuser/.vscode-server
    code . 2>&1 | tee /logs/server_dir_home_old_dir.stdout
    [[ ${PIPESTATUS[0]} = 1 ]] || fail "Should have exited unsuccessfully"
    assert_grep "$HOME/.vscode-server is not a symlink - this is probably a left-over." \
                /logs/server_dir_home_old_dir.stdout
}

### HOME=<somehwere else

mock_server_dir_unknown() {
    do_mock_server_dir /home/otheruser
}

test_server_dir_unknown() {
    code . 2>&1 | tee /logs/server_dir_unknown.stdout
    [[ ${PIPESTATUS[0]} = 1 ]] || fail "Should have exited unsuccessfully"
    assert_grep "\$HOME in container config is: '/home/otheruser' - don't know how to handle this." \
                /logs/server_dir_unknown.stdout
}

