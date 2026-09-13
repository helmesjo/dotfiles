#!/bin/bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

# helix doesn't have a 'hx' bin on arch
if ! hx --version >/dev/null 2>&1; then
  helix_path=$(which helix)
  helix_bindir=$(dirname $helix_path)
  sudo ln -sv $helix_path $helix_bindir/hx
fi