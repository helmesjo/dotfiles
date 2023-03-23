#!/bin/bash
set -eu -o pipefail

# helix doesn't have a 'hx' bin on arch
if ! hx --version >/dev/null 2>&1; then
  helix_path=$(which helix)
  helix_bindir=$(dirname $helix_path)
  sudo ln -sv $helix_path $helix_bindir/hx
fi