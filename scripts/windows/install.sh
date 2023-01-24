#!/usr/bin/env bash

set -eu -o pipefail

function on_error {
    echo "Failed..."
    exit 1
}
trap on_error ERR

echo "Installing required packages..."

file_dir=`dirname $(readlink -f $BASH_SOURCE)`

$file_dir/install-choco.sh
$file_dir/install-scoop.sh

#chocopkgs=()
scooppkgs=(
  bat
  fzf
  delta
  helix
  llvm             # lldb-vscode
  Office-Code-Pro  # Source Code Pro Font
  ripgrep
  tre-command
)

#choco install --yes ${chocopkgs[@]}
scoop bucket add nerd-fonts
scoop install --no-cache ${scooppkgs[@]}