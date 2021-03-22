#!/bin/bash

# shellcheck disable=SC1091
name="$(. /run/.containerenv && echo "$name")"

### Safety checks

if [ "$name" != toolbox-vscode-test ] || [ "$HOME" != /home/testuser ] ; then
    echo "Tests must be run inside a container via run-tests.sh"
    exit 1
fi

###

TEST_FILE=$1
TEST_NAME=$2
export TEST_FILE TEST_NAME

#### Clean up any old files

find /home/testuser -mindepth 1 -delete
sudo find /root -mindepth 1 -delete
sudo rm -rf /.vscode-server

### Set up bin directory

bindir=/home/testuser/.local/bin
mkdir -p /home/testuser/.local/bin
PATH=$bindir:$PATH

ln -s /source/code.sh $bindir/code
ln -s /source/tests/framework/mock-flatpak-spawn.sh $bindir/flatpak-spawn

### Functions for tests

assert_contents() {
    cat > /logs/expected
    if ! cmp -s /logs/expected "$1" ; then
        diff -u --label Expected --label "$1" /logs/expected "$1" 1>&2
        exit 1
    fi
}

### Run the test

# shellcheck disable=SC1090
. "$TEST_FILE"
"test_$TEST_NAME"

