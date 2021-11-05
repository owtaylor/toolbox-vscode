# shellcheck shell=bash

mock_no_symlink() {
    :
}

test_no_symlink() {
    mkdir ~/project
    cd ~/project || exit 1
    if /source/code.sh --toolbox-verbose . > out 2>&1 ; then
        echo "Running script directly should fail"
        return 1
    fi || :
    assert_contents out <<'EOF'
code.sh: Only symlinked installation currently supported
EOF
}

mock_two_symlinks() {
    :
}

test_two_symlinks() {
    mkdir ~/project
    cd ~/project || exit 1
    ln -s /home/testuser/.local/bin/code .
    if ./code --toolbox-verbose . > out 2>&1 ; then
        echo "Running script through double symlink should fail"
        return 1
    fi || :
    assert_contents out <<'EOF'
code: ./code should be a symlink to code.sh in the toolbox-vscode checkout
EOF
}
