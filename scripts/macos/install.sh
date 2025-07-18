#!/usr/bin/env bash

set -eu -o pipefail

file_dir=`dirname $(readlink -f $BASH_SOURCE)`
$file_dir/install-brew.sh
$file_dir/install-zsh-pure.sh
$file_dir/install-zsh-autosuggestions.sh
$file_dir/install-zsh-syntax-highlighting.sh
$file_dir/install-zsh-history-substring-search.sh
# $file_dir/install-pkgin.sh

brewpkgs=(
  # Core
  alacritty   # terminal
  alt-tab     # alt-tab switch windows, not apps
  bash
  bat
  coreutils
  eza
  fzf
  git
  ripgrep
  tre-command # tree replacement
  koekeishiya/formulae/yabai # tiling window manager
  koekeishiya/formulae/skhd  # hotkey daemon
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
  yaml-language-server
  taplo                  # toml
  marksman               # markdown (code assist)
  markdown-oxide         # markdown (lsp)
  # Fonts
  font-jetbrains-mono
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

# remove old service file because homebrew changes binary path
if command -v yabai >/dev/null; then
  yabai --uninstall-service 2>/dev/null || true
fi

if command -v skhd >/dev/null; then
  skhd --uninstall-service 2>/dev/null || true
fi

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
