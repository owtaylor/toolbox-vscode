#!/bin/bash

# Simple ansi-formatted echo

term() {
    local fmt n
    fmt="$1"
    shift
    if [ "$1" = "-n" ] ; then
        n=-n
        shift
    fi
    if [ -t 1 ] ; then
        echo -ne "$fmt"
        echo -n "$@"
        echo $n -e "\033[0m"
    else
        echo $n "$@"
    fi
}

bold() {
    term "\033[1m" "$@"
}

red() {
    term "\033[1m\033[31m" "$@"
}

green() {
    term "\033[1m\033[32m" "$@"
}

### Safety checks

# shellcheck disable=SC1091
name="$(. /run/.containerenv && echo "$name")"

if [ "$name" != toolbox-vscode-test ] || [ "$HOME" != /home/testuser ] ; then
    echo "Tests must be run inside a container via run-tests.sh"
    exit 1
fi

### Collect tests

test_files=()
test_names=()

for f in /source/tests/test-*.sh ; do
    while read -r _ _ fn ; do
        if [[ $fn = test_* ]] ; then
            name="${fn#test_}"

            if [[ $# -eq 0 ]] ; then
                include=true
            else
                include=false
                for (( i=1 ;  i <= $# ; i++ )) ; do
                    # shellcheck disable=SC2053
                    # Intentionally don't quote the right side to enable globbing
                    if [[ "$name" = ${!i} ]] ; then
                        include=true
                    fi
                done
            fi
            if $include ; then
                test_files+=("$f")
                test_names+=("$name")
            fi
        fi
    done < <(
        # shellcheck disable=SC1090
        . "$f"
        declare -F
    )
done

### Run tests

total=${#test_files[@]}

if [[ $total -eq 0 ]] ; then
    red "No tests found"
    exit 1
fi

# Remove old files from /logs
find /logs -mindepth 1 -not -name .gitkeep -delete

succeeded=0
for ((i = 0; i < total; i++)) ; do
    test_file="${test_files[i]}"
    test_name="${test_names[i]}"

    bold -n "$(basename "$test_file"):$test_name ... "

    if /source/tests/framework/run-one-test.sh \
            "$test_file" "$test_name"  > "/logs/$test_name.out" 2>&1 ; then
        green OK
        succeeded="$((succeeded + 1))"
    else
        red FAILED
        echo ---
        cat "/logs/$test_name.out"
        echo ---
    fi
done

### Print summary

if [[ $total -eq $succeeded ]] ; then
    green "Success: $total/$succeeded"
    exit 0
else
    red "Failed: $((total - succeeded))/$succeeded"
    exit 1
fi
