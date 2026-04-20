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
$file_dir/install-zsh-antidote.sh
$file_dir/install-win32yank.sh

wingetpkgs=(
  Alacritty.Alacritty
  sharkdp.bat                 # cat
  Solidiquis.Erdtree          # tree & ls
  ajeetdsouza.zoxide          # cd
  alexpasmantier.television   # multi-purpose fuzzy finder
  tldr-pages.tlrc             # man
  Helix.Helix
  DEVCOM.JetBrainsMonoNerdFont
  junegunn.fzf
  dandavison.delta            # git diff
  StephanDilly.gitui
  LLVM.LLVM                   # clangd, lldb-vscode
  LGUG2Z.komorebi             # tiling window manager
  LGUG2Z.whkd                 # hotkey override
  Flow-Launcher.Flow-Launcher # app launcher
  BurntSushi.ripgrep.MSVC
  python3
  sxyazi.yazi                 # file manager
  # language servers
  LuaLS.lua-language-server
  tamasfe.taplo               # toml
  markdown-oxide              # markdown
  Zen-Team.Zen-Browser
)
pacmanpkgs=(
  zsh
)

winget install --accept-source-agreements \
               --accept-package-agreements \
               --disable-interactivity \
               --ignore-warnings \
               --no-upgrade \
                 ${wingetpkgs[@]}

# Run a command in a new mintty window and wait for it to finish.
# mintty --hold never closes the window immediately on exit so the
# wait below can detect completion rather than hanging indefinitely.
function run_in_mintty {
  mintty --hold never -e bash -lc "$*" &
  wait $! || true
}

# MSYS2's installer shuts down running MSYS2 sessions, so run it in a
# separate cmd window that survives the shutdown and wait for it to finish.
if ! winget list | grep 'MSYS2' >/dev/null; then
  cmd.exe //c "start /wait winget install --disable-interactivity --ignore-warnings --accept-source-agreements --accept-package-agreements MSYS2.MSYS2"
# Upgrading msys2-runtime terminates the running shell mid-upgrade, so a
# second pass is required to finish. Check before starting so we only pay
# the cost when the runtime actually needs upgrading.
elif pacman -Qu 2>/dev/null | grep -q '^msys2-runtime '; then
  run_in_mintty 'pacman --noconfirm -Syu'
fi

pacman --noconfirm -Syu ${pacmanpkgs[*]}

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

# upgrade only those that aren't 'pinned' (otherwise the command fails).
wingetpinned=($(winget pin list | awk 'NR>2 {print $2}' | tr '\n' ' '))
wingetupgrade=($(printf '%s\n' "${wingetpkgs[@]}" | grep -v -Fxf <(echo ${wingetpinned[@]})))
winget upgrade --ignore-warnings \
               --accept-source-agreements \
               --accept-package-agreements \
               ${wingetupgrade[@]}
