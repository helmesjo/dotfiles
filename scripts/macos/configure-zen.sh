#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

dir="$HOME/Library/Application Support/zen"

# Your actual logic here (example)
if [[ -d "$dir" && ! -L "$dir" ]]; then
  mv -fv "$dir" "${dir}.bak"
  ln -sv ~/.config/zen "$dir"
else
  ls -ld "$dir" 2>/dev/null
fi
