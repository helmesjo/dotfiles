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

wingetpkgs=(
  eza-community.eza        # modern ls
  sharkdp.bat              # modern cat
  ca.duan.tre-command      # modern tree
  ajeetdsouza.zoxide       # modern cd
  Helix.Helix
  junegunn.fzf
  dandavison.delta         # git diff
  StephanDilly.gitui
  LLVM.LLVM                # clangd, lldb-vscode
  BurntSushi.ripgrep.MSVC
  gerardog.gsudo           # sudo
)
# Fonts must be installed as admin
chocopkgs_admin=(
  jetbrainsmono
)
pacmanpkgs=(
  fish
)

winget install ${wingetpkgs[@]}
sudo choco install --yes ${chocopkgs_admin[@]}
cmd.exe //C C:/msys64/msys2_shell.cmd -defterm -here -no-start -ucrt64 -shell \
  bash -c "pacman --noconfirm -Syu && pacman --noconfirm -Sy $pacmanpkgs"
