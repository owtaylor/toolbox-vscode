#!/bin/bash

shopt -s nullglob

if [ "$1" != --host ] ; then
    echo "$0: only flatpak-spawn --host is supported" 1>&2
    exit 1
fi

shift
args=("$@")

match() {
    local index m
    local -a match=("$@")

    for (( index=0 ; index < $# ; index++ )) ; do
        m=${match[$index]}
        if [[ $m = @ ]] ; then
            return 0
        fi
        if [[ $m != "${args[$index]}" ]] ; then
            return 1
        fi
        index=$((index + 1))
    done
}

echo "$*" >> "/logs/$TEST_NAME.cmd"

if [ -n "$TEST_FILE" ] ; then
    # shellcheck disable=SC1090
    . "$TEST_FILE"
    "mock_$TEST_NAME"
fi

# shellcheck disable=SC1091
. /source/tests/default-mock.sh

echo "$0: unmatched: $*" 1>&2
exit 1
