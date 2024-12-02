#!/usr/bin/env bash

set -eu -o pipefail

function on_error {
    echo "Failed..."
    exit 1
}
trap on_error ERR

if ! command -v gsudo &>/dev/null; then
  winget install --accept-source-agreements --accept-package-agreements \
    gerardog.gsudo # sudo
fi

# Installing packages requires elevated priviliges, so we ask once.
if [[ "$HOME" != $(cygpath -u "$USERPROFILE") ]] || ! net session > /dev/null 2>&1; then
  # Must run with correct home directory,
  # else it'll create it's own within msys2.
  MSYS=winsymlinks:nativestrict
  HOME=$(cygpath -u "$USERPROFILE")
  this_script="$(cygpath -u "$(readlink -f $BASH_SOURCE)")"

  echo "Re-running as admin with HOME=$HOME"
  "$(cygpath -u "$PROGRAMFILES/gsudo/Current/gsudo")" \
    bash -c "$this_script"
    exit $?
fi

echo "Installing required packages..."

file_dir=`dirname $(readlink -f $BASH_SOURCE)`
$file_dir/install-zsh-pure.sh
$file_dir/install-zsh-autosuggestions.sh
$file_dir/install-zsh-syntax-highlighting.sh
$file_dir/install-zsh-history-substring-search.sh

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
  python3
)
# Fonts must be installed as admin
chocopkgs=(
  nerd-fonts-JetBrainsMono
)
pacmanpkgs=(
  zsh
)

winget install --accept-source-agreements --accept-package-agreements \
  ${wingetpkgs[@]}

# Pass 'yes' to any prompt from MSYS2. It also always returns error,
# so always assume success.
if ! command -v winget list | grep 'MSYS2' >/dev/null; then
  yes | winget install MSYS2.MSYS2 || true
fi
# finish up MSYS2 install in a detached shell since it'll terminate the shell
# the first time (to wrap up the install).
C:/msys64/msys2_shell.cmd -defterm -here -no-start -ucrt64 -shell \
                bash -c "exec pacman --noconfirm -Syu; exit 0"
C:/msys64/msys2_shell.cmd -defterm -here -no-start -ucrt64 -shell \
                bash -c "pacman --noconfirm -S ${pacmanpkgs[*]}"

# vc++ build tools (if not already available):
if ! command -v cl.exe &>/dev/null; then
  winget install --force --id=Microsoft.VisualStudio.2022.BuildTools \
                 --override "--quiet --wait \
                   --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
                   --add Microsoft.VisualStudio.Component.Windows11SDK.26100 \
                 "
fi

# font:
choco install --yes ${chocopkgs[@]}
