#!/usr/bin/env bash

set -eu -o pipefail

echo "Installing required packages..."

file_dir=`dirname $(readlink -f $BASH_SOURCE)`

$file_dir/install-brew.sh
$file_dir/install-pkgin.sh

brewpkgs=(
  # Core
  alt-tab     # alt-tab switch windows, not apps
  bash
  bat
  broot       # interactive 'tree' replacement
  coreutils
  exa
  fish
  fzf
  ripgrep
  # TUI/GUI
  gitui
  # Dev
  git-delta
  helix
  homebrew/cask-fonts/font-source-code-pro
  npm
  ## Debugging
  llvm        # lldb-vscode
  ## Languge Server Protocol
  bash-language-server
  lua-language-server
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
