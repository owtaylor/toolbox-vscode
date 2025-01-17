# shellcheck shell=bash

mock_arg_parsing() {
    :
}

ENCODED_REMOTE=746f6f6c626f782d7673636f64652d74657374
URI_PREFIX=vscode-remote://attached-container+$ENCODED_REMOTE

assert_args() {
    tail -n 1 /logs/arg_parsing.cmd > /logs/arg_parsing.cmd.last
    assert_contents /logs/arg_parsing.cmd.last <<EOF
flatpak run com.visualstudio.code --remote attached-container+$ENCODED_REMOTE $*
EOF
}

test_arg_parsing() {
    mkdir MyProject

    code
    assert_args --new-window

    code .
    assert_args --folder-uri "$URI_PREFIX/home/testuser"

    code MyProject
    assert_args --folder-uri "$URI_PREFIX/home/testuser/MyProject"

    code /home/testuser/MyProject
    assert_args --folder-uri "$URI_PREFIX/home/testuser/MyProject"

    # Anything that isn't an existing folder should be treated as a file
    code /home/testuser/somefile.py
    assert_args --file-uri "$URI_PREFIX/home/testuser/somefile.py"

    # Test escaping
    code /home/testuser/"%#?.py"
    assert_args --file-uri "$URI_PREFIX/home/testuser/%25%23%3F.py"

    code --file-uri=file:///home/testuser
    assert_args --file-uri=file:///home/testuser

    code --file-uri file:///home/testuser
    assert_args --file-uri file:///home/testuser

    code --max-memory=4096
    assert_args --max-memory=4096 --new-window

    code --max-memory 4096
    assert_args --max-memory 4096 --new-window

    code --help
    assert_args --help
}
