Coding Style
------------
Code should be clean when checked with [shellcheck](https://github.com/koalaman/shellcheck).
The recommended
[ShellCheck Visual Studio code extension](https://marketplace.visualstudio.com/items?itemName=timonwong.shellcheck)
checks that while you are editing, or `./shellcheck.sh` can be run manually.

 * Bash extensions are fine to use, and *should* be used:
    * use arrays rather than word splitting
    * use arithmetic expansion `$((i + 1))` rather than `expr`
 * Lines should be kept to 100 characters when possible.
 * When in doubt, quote defensively - .e.g, pretend like `$HOME` might have spaces in it.

Tests
-----
Any pull requests should come with new tests or extensions to existing tests
that check the correct functionality of new code.

`./runtests.sh` runs all the tests inside a podman container that emulates the toolbox container.

`./runtests.sh --build` forces the podman container to be rebuilt (not normally neded)

`./runtests.sh <glob>` runs only tests matching a particular glob.

Each test is defined as two shell functions inside a file `tests/test-<group>.sh`. Simplified example:

``` bash
# Matches arguments to flatpak-spawn --host
# and performs actions
# Run before tests/default-mock.sh
mock_running() {
    # @ can be used matches all remaining arguments
    if match flatpak ps --columns=instance,application ; then
        echo "123456 com.visualstudio.code"
        exit 0
    fi
}

# Perform the tests
test_running() {
    # Do any necessary setup

    # Run the wrapper script
    code .

    # Check generated files and logs
    # /logs/<name>.cmd contains arguments to all flatpak-spawn --host commands run
    if ! grep -q 'flatpak-enter 123456' /logs/running.cmd ; then
        echo "Failed to find flatpak-enter"
        exit 1
    fi
}
```
After running the tests,
the contents of /logs within the container can be found in the ./logs directory at the toplevel.
