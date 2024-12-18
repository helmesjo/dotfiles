#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

## Keyboard repeat delay & speed
defaults write -g InitialKeyRepeat -int 10 # normal minimum is 15 (225 ms)
defaults write -g KeyRepeat -int 1 # normal minimum is 2 (30 ms)
