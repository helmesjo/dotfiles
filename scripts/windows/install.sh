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
# scooppkgs=(
# )
# scooppkgs_global=(
# )

winget install ${wingetpkgs[@]}
sudo choco install --yes ${chocopkgs_admin[@]}
# scoop install sudo --no-cache
# scoop bucket add nerd-fonts
# scoop install --no-cache ${scooppkgs[@]}
# sudo scoop install --global --no-cache ${scooppkgs_global[@]}
