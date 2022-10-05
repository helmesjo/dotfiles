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
  iterm2
  llvm      # lldb-vscode
  lua-language-server
  npm
  ripgrep
)

pkginpkgs=(
  tree
)

pippkgs=(
  cmake-language-server
)

npmpkgs=(
  bash-language-server
)

brew install -f ${brewpkgs[@]}
sudo pkgin -y install ${pkginpkgs[@]}
yes | pip3 install ${pippkgs[@]}
npm install -g ${npmpkgs[@]}