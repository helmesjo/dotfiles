#!/usr/bin/env bash

set -eu -o pipefail

echo "Installing required packages..."

dotfiles_root=`dirname $(readlink -f $BASH_SOURCE)`

brewpkgs=(
  bat
  helix
)

pkginpkgs=(
  fish
  fzf
  git-delta
  ripgrep
)

brew install -f ${brewpkgs[@]}
sudo pkgin -y install ${pkginpkgs[@]}