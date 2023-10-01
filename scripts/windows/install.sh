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

wingetpkgs=(
  eza-community.eza
  Helix.Helix
)
#chocopkgs=()
scooppkgs=(
  bat
  fzf
  delta
  gitui
  llvm             # lldb-vscode
  ripgrep
  tre-command
)
# Fonts must be installed globally
scooppkgs_global=(
  Office-Code-Pro  # Source Code Pro Font
)

winget install ${wingetpkgs[@]}
#choco install --yes ${chocopkgs[@]}
scoop install sudo --no-cache
scoop bucket add nerd-fonts
scoop install --no-cache ${scooppkgs[@]}
sudo scoop install --global --no-cache ${scooppkgs_global[@]}
