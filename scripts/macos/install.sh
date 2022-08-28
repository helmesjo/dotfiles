#!/usr/bin/env bash

set -eu -o pipefail

echo "Installing required packages..."

file_dir=`dirname $(readlink -f $BASH_SOURCE)`

$file_dir/install-brew.sh
$file_dir/install-pkgin.sh

brewpkgs=(
  bat
  fish
  fzf
  git-delta
  helix
  ripgrep
)

pkginpkgs=(
  tree
)

brew install -f ${brewpkgs[@]}
sudo pkgin -y install ${pkginpkgs[@]}