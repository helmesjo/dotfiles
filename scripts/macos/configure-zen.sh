#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

script_dir=$(dirname "$(readlink -f "$BASH_SOURCE")")
dotfiles_root=$(git -C "$script_dir" rev-parse --show-toplevel)

# Symlink app-support dir so Zen uses XDG-style ~/.config/zen on macOS
dir="$HOME/Library/Application Support/zen"
if [[ -d "$dir" && ! -L "$dir" ]]; then
  mv -fv "$dir" "${dir}.bak"
  ln -sv ~/.config/zen "$dir"
fi

# Install LaunchAgent that sets XRE_PROFILE_PATH/XRE_PROFILE_LOCAL_PATH for GUI apps
plist_src="$dotfiles_root/configs/macos/Library/LaunchAgents/org.user.zen-env.plist"
plist_dst="$HOME/Library/LaunchAgents/org.user.zen-env.plist"
if [[ "$(readlink "$plist_dst" 2>/dev/null)" != "$plist_src" ]]; then
  mkdir -p "$HOME/Library/LaunchAgents"
  launchctl unload "$plist_dst" 2>/dev/null || true
  ln -sfv "$plist_src" "$plist_dst"
  launchctl load -w "$plist_dst"
fi
