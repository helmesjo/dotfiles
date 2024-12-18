#!/usr/bin/env bash

set -eu -o pipefail

function on_error {
    echo "Failed..."
    exit 1
}
trap on_error ERR

if ! command -v gsudo &>/dev/null; then
  winget install --disable-interactivity \
                 --ignore-warnings \
                 --accept-source-agreements \
                 --accept-package-agreements \
                 gerardog.gsudo # sudo
fi

file_dir=`dirname $(readlink -f "${BASH_SOURCE[0]:-$0}")`
$file_dir/install-zsh-pure.sh
$file_dir/install-zsh-autosuggestions.sh
$file_dir/install-zsh-syntax-highlighting.sh
$file_dir/install-zsh-history-substring-search.sh

wingetpkgs=(
  Alacritty.Alacritty
  eza-community.eza        # modern ls
  sharkdp.bat              # modern cat
  ca.duan.tre-command      # modern tree
  ajeetdsouza.zoxide       # modern cd
  Helix.Helix
  DEVCOM.JetBrainsMonoNerdFont
  junegunn.fzf
  dandavison.delta         # git diff
  StephanDilly.gitui
  LLVM.LLVM                # clangd, lldb-vscode
  BurntSushi.ripgrep.MSVC
  python3
)
pacmanpkgs=(
  zsh
)

winget install --no-upgrade \
               --disable-interactivity \
               --ignore-warnings \
               --accept-source-agreements \
               --accept-package-agreements \
  ${wingetpkgs[@]}

# execute Msys stuff in separate terminal since it
# needs to "restart" after install.
CMD_EXE=($(dir.exe $(which cmd.exe)))
case "$(uname -s)" in
    MINGW*) CMD_EXE+=(start //wait cmd //C);;
    *)      CMD_EXE+=(start /wait cmd /C);;
esac
if ! winget list | grep 'MSYS2' >/dev/null; then
  ${CMD_EXE[@]} "winget install --disable-interactivity \
                                     --ignore-warnings \
                                     MSYS2.MSYS2 \
                     || exit 0"
fi

# finish up MSYS2 install, again in a separate process since it'll
# terminate the shell the first time (to wrap up the install).
${CMD_EXE[@]} "C:/msys64/msys2_shell.cmd -defterm -here -no-start -ucrt64 -shell \
                    bash -c 'pacman --noconfirm -Syu' \
                    || exit 0"
${CMD_EXE[@]} "C:/msys64/msys2_shell.cmd -defterm -here -no-start -ucrt64 -shell \
                    bash -c 'pacman --noconfirm -S ${pacmanpkgs[*]}' \
                    || exit 0"

# vc++ build tools (if not already available in path or installed):
if ! $file_dir/.vsdevenv.sh &>/dev/null; then
  winget install --force \
                 --disable-interactivity \
                 --accept-source-agreements \
                 --accept-package-agreements \
                 --id=Microsoft.VisualStudio.2022.BuildTools \
                 --override "--quiet --wait \
                   --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
                   --add Microsoft.VisualStudio.Component.Windows11SDK.26100 \
                 "
fi

winget upgrade --accept-source-agreements \
               --accept-package-agreements \
               ${wingetpkgs[@]}
