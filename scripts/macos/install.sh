#!/usr/bin/env bash

set -eu -o pipefail

echo "Installing required packages..."

file_dir=`dirname $(readlink -f $BASH_SOURCE)`
$file_dir/install-brew.sh
$file_dir/install-zsh-pure.sh
$file_dir/install-zsh-autosuggestions.sh
$file_dir/install-zsh-syntax-highlighting.sh
$file_dir/install-zsh-history-substring-search.sh
# $file_dir/install-pkgin.sh

brewpkgs=(
  # Core
  alt-tab     # alt-tab switch windows, not apps
  bash
  bat
  coreutils
  eza
  fzf
  git
  ripgrep
  tre-command # tree replacement
  zoxide      # cd replacement
  # prompt
  zsh
  zsh-completion
  # TUI/GUI
  gitui
  # Dev
  git-delta
  helix
  npm
  ## Debugging
  llvm        # lldb-vscode
  ## Languge Server Protocol
  bash-language-server
  cmake-language-server
  lua-language-server
  # Fonts
  homebrew/cask-fonts/font-jetbrains-mono-nerd-font
)
brewcasks=(
  git-credential-manager
)

# pkginpkgs=(
# )

# pippkgs=(
# )

# npmpkgs=(
# )
brew install -f ${brewpkgs[@]}
brew install -f --cask ${brewcasks[@]}
brew update -f
# sudo pkgin -y install ${pkginpkgs[@]}
# python3 -m venv ~/.local --system-site-packages
# ~/.local/bin/pip install --no-input ${pippkgs[@]} --upgrade
# npm install -g ${npmpkgs[@]}

# Remove unused/orphaned packages
brew autoremove
# sudo pkgin autoremove
