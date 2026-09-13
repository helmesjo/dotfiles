#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR
unalias -a # disable aliases for script

## Keyboard repeat delay & speed
defaults write -g InitialKeyRepeat -int 10             # normal minimum is 15 (225 ms)
defaults write -g KeyRepeat -int 1                     # normal minimum is 2 (30 ms)
defaults write -g ApplePressAndHoldEnabled -bool false # disable "press & hold" pallete
