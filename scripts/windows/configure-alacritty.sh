#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

export MSYS=winsymlinks:nativestrict

# Alacritty on Windows uses the system ConPTY (conhost.exe) via CreatePseudoConsole(),
# which has a known non-atomic frame rendering bug: when zsh syntax highlighting redraws
# the line (cursor-hide + reposition + redraw + cursor-show), conhost emits intermediate
# frames that make the cursor visibly jump to column 0 on each keystroke.
#
# Since alacritty/alacritty#6994 (merged 2023), Alacritty dynamically loads conpty.dll
# from its own directory if present, bypassing the system conhost entirely. Microsoft
# publishes a standalone conpty.dll + OpenConsole.exe in the nupkg attached to each
# Windows Terminal GitHub release (the nupkg is a plain zip, no NuGet tooling required).
#
# This script downloads the latest conpty.dll and OpenConsole.exe from the Windows
# Terminal GitHub release and copies them next to alacritty.exe, so Alacritty
# automatically picks them up on next launch.

# Find Alacritty install dir
alacritty_exe=$(command -v alacritty.exe 2>/dev/null || command -v alacritty 2>/dev/null || true)
if [[ -z "$alacritty_exe" ]]; then
  echo "WARN: alacritty not found in PATH, nothing to configure"
  exit 0
fi
alacritty_dir=$(dirname "$alacritty_exe")

echo "  - Alacritty: $alacritty_dir"

# Detect arch
case "$(uname -m)" in
  x86_64)  arch=x64   ;;
  i686)    arch=x86   ;;
  aarch64) arch=arm64 ;;
  *)       echo "WARN: unsupported arch $(uname -m), cannot install ConPTY binaries" >&2; exit 0 ;;
esac

# Fetch latest Windows Terminal release and find the ConPTY nupkg asset URL
nupkg_url=$(curl -fsSL "https://api.github.com/repos/microsoft/terminal/releases/latest" \
  | grep -o 'https://[^"]*ConPTY[^"]*\.nupkg' \
  | head -1)

if [[ -z "$nupkg_url" ]]; then
  echo "WARN: could not find ConPTY nupkg in latest Windows Terminal release" >&2
  exit 0
fi

# Extract version from URL (e.g. "1.24.260402001" from "...ConPTY.1.24.260402001.nupkg")
latest_version=$(basename "$nupkg_url" .nupkg | sed 's/.*ConPTY\.//')

# Bail early if already up to date (version stored in sidecar file after each install)
version_file="$alacritty_dir/conpty.version"
if [[ -f "$version_file" ]]; then
  installed_version=$(cat "$version_file")
  if [[ "$(printf '%s\n%s' "$latest_version" "$installed_version" | sort -V | head -1)" == "$latest_version" ]]; then
    echo "  - conpty already up to date (installed=$installed_version >= latest=$latest_version)"
    exit 0
  fi
  echo "  - Updating conpty: $installed_version -> $latest_version ($nupkg_url)"
else
  echo "  - Downloading conpty $latest_version ($nupkg_url)"
fi

# Download and extract
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fL# "$nupkg_url" -o "$tmp/conpty.zip"
echo "  - Downloaded: $(ls -h "$tmp/conpty.zip")"
unzip -q "$(cygpath -w "$tmp/conpty.zip")" -d "$(cygpath -w "$tmp")"

conpty_dll=$(find "$tmp" -name "conpty.dll"    -path "*${arch}*" | head -1)
openconsole=$(find "$tmp" -name "OpenConsole.exe" -path "*${arch}*" | head -1)

if [[ -z "$conpty_dll" ]]; then
  echo "WARN: conpty.dll (${arch}) not found in downloaded package" >&2
  exit 0
fi
if [[ -z "$openconsole" ]]; then
  echo "WARN: OpenConsole.exe (${arch}) not found in downloaded package" >&2
  exit 0
fi

# Copy into Alacritty's dir (requires elevation if in Program Files)
gsudo bash -c "cp -v '$conpty_dll' '$alacritty_dir/' && cp -v '$openconsole' '$alacritty_dir/' && printf '%s' '$latest_version' > '$alacritty_dir/conpty.version'"
