#!/usr/bin/env bash

set -eu -o pipefail

function on_error {
    echo "Failed..."
    sleep 5
    exit 1
}
trap on_error ERR

echo "Installing required packages..."

file_dir=`dirname $(readlink -f $BASH_SOURCE)`

$file_dir/install-choco.sh

pkgs=(
  bat
  fzf
  delta
  helix
  #llvm      # lldb-vscode
  ripgrep
  sourcecodepro
  tree
)

choco install --yes ${pkgs[@]}
