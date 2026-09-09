#!/usr/bin/env bash
set -eu -o pipefail
unalias -a

# Builds and installs conpty-paste.exe: the Ctrl+Shift+V paste router for
# Windows ConPTY terminals.
#
# Source: ~/.config/alacritty/conpty-paste.c  (compiled with MinGW GCC)
# Target: ~/.local/bin/conpty-paste.exe
#
# Rebuilds when the source is newer than the binary or the binary is missing.
# Compiles to a temp file first, then renames, so the target is never partial.

file_dir=`dirname $(readlink -f $BASH_SOURCE)`
GCC=$(which gcc) || { echo "ERROR: gcc not found - install mingw-w64 gcc" >&2; exit 1; }
src="$HOME/.config/alacritty/conpty-paste.c"
out="$HOME/.local/bin/conpty-paste.exe"
mkdir -p "$HOME/.local/bin"

if [[ ! -f "$out" || "$src" -nt "$out" ]]; then
  echo "  - compiling conpty-paste.exe"
  tmp="$file_dir/$(basename "$out")"
  "$GCC" -mwindows -O2 -o "$tmp" "$src"
  printf "%s" "  - "
  mv -v "$tmp" "$out"
else
  echo "  - conpty-paste.exe is up to date"
fi

# Add ~/.local/bin to the Windows user PATH so conpty-paste.exe is reachable
# from Alacritty's command binding.
# Read the registry directly first to avoid a slow PowerShell invocation when
# the entry is already present.
local_bin_win=$(cygpath -w "$HOME/.local/bin")
win_user_path=$(MSYS2_ARG_CONV_EXCL="*" reg.exe query "HKCU\\Environment" /v PATH 2>/dev/null \
  | tr -d '\r' | grep -i 'REG_' | sed 's/.*REG_[A-Z_]*[[:space:]]*//' || true)
if [[ "$win_user_path" != *"$local_bin_win"* ]]; then
  powershell -NoProfile -NonInteractive -Command "
    \$bin = '$local_bin_win'
    \$cur = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
    if (\$cur -notlike \"*\$bin*\") {
      [System.Environment]::SetEnvironmentVariable('PATH', \"\$cur;\$bin\", 'User')
      Write-Host \"  - added \$bin to Windows user PATH (restart Alacritty to apply)\"
    }
  "
fi
