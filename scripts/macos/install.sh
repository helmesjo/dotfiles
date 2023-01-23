#!/usr/bin/env bash

set -eu -o pipefail

echo "Installing required packages..."

file_dir=`dirname $(readlink -f $BASH_SOURCE)`

$file_dir/install-brew.sh
$file_dir/install-pkgin.sh

brewpkgs=(
  bash
  bat
  coreutils
  exa
  fish
  fzf
  git-delta
  helix
  homebrew/cask-fonts/font-source-code-pro
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
brew update -f
sudo pkgin -y install ${pkginpkgs[@]}
python3 -m pip install --no-input ${pippkgs[@]} --upgrade
npm install -g ${npmpkgs[@]}

# Remove unused/orphaned packages
brew autoremove
sudo pkgin autoremove
