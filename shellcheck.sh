#!/bin/bash

find . -name '*.sh' -a \! -name '.#*' -print0 | xargs -0 shellcheck
