#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

# To install useful key bindings and fuzzy completion:
# NOTE: Only needed once, now changes are checked in to repo already.
# $(brew --prefix)/opt/fzf/install
