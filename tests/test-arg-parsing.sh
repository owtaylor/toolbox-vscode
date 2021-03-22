# shellcheck shell=bash

mock_arg_parsing() {
    :
}

ENCODED_REMOTE=746f6f6c626f782d7673636f64652d74657374

assert_args() {
    tail -n 1 /logs/arg_parsing.cmd > /logs/arg_parsing.cmd.last
    assert_contents /logs/arg_parsing.cmd.last <<EOF
flatpak run com.visualstudio.code --remote attached-container+$ENCODED_REMOTE $*
EOF
}

test_arg_parsing() {
    code
    assert_args --new-window

    code .
    assert_args /home/testuser

    code MyProject
    assert_args /home/testuser/MyProject

    code /MyProject
    assert_args /MyProject

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
