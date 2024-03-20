#!/usr/bin/env bash

set -eu -o pipefail

function on_error {
    echo "Failed..."
    exit 1
}
trap on_error ERR

echo "Installing required packages..."

file_dir=`dirname $(readlink -f $BASH_SOURCE)`

wingetpkgs=(
  Alacritty.Alacritty
  Chocolatey.Chocolatey
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
  git
)

winget install ${wingetpkgs[@]}

# Msys: Deal with '/' being parsed as path & not cmd flag
case "$(uname -o)" in
    Msys) CMD_EXE=(cmd //C);;
    *)    CMD_EXE=(cmd /C);;
esac

# Pass 'yes' to any prompt from MSYS2. It also always returns error,
# so always assume success.
yes | winget install MSYS2.MSYS2 || true
# finish up MSYS2 install in a detached shell since it'll terminate the shell
# the first time (to wrap up the install).
${CMD_EXE[@]} C:/msys64/msys2_shell.cmd -defterm -here -no-start -ucrt64 -shell \
                bash -c "exec pacman --noconfirm -Syu; exit 0"

test -f "C:/msys64/msys2_shell.cmd"
${CMD_EXE[@]} C:/msys64/msys2_shell.cmd -defterm -here -no-start -ucrt64 -shell \
                bash -c "yes | pacman --noconfirm -Syu && pacman --noconfirm -Sy $pacmanpkgs"

# vc++ build tools:
winget install --force --id=Microsoft.VisualStudio.2022.BuildTools \
               --override "--quiet --wait --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64"

# font:
"$(cygpath -u "$PROGRAMFILES/gsudo/Current/gsudo")" choco install --yes ${chocopkgs_admin[@]}
