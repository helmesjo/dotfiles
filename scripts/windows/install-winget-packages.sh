#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

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

winget install --accept-source-agreements \
               --accept-package-agreements \
               --disable-interactivity \
               --ignore-warnings \
               --no-upgrade \
                 ${wingetpkgs[@]}

# upgrade only those that aren't 'pinned' (otherwise the command fails).
wingetpinned=($(winget pin list | awk 'NR>2 {print $2}'))
wingetupgrade=($(printf '%s\n' "${wingetpkgs[@]}" | grep -v -Fxf <(printf '%s\n' "${wingetpinned[@]}")))
winget upgrade --disable-interactivity \
               --ignore-warnings \
               --accept-source-agreements \
               --accept-package-agreements \
               ${wingetupgrade[@]}
