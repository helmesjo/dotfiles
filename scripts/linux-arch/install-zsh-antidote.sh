#!/usr/bin/env bash
set -eu -o pipefail

URL="https://github.com/mattmc3/antidote"
NAME=$(basename $URL)
DIR="${ZDOTDIR:-$HOME}/.antidote"

# Fetch latest release tag from GitHub: vX.Y.Z
latest=$(curl -sf "https://api.github.com/repos/mattmc3/antidote/releases/latest" | \
  awk -F'"' '/"tag_name"/{print $4}')
latest_version="${latest#v}"

# Get currently installed version: 'antidote version X.Y.Z (abc1234)'
installed_version=""
if command -v antidote >/dev/null 2>&1; then
  installed_version=$(antidote --version 2>/dev/null | awk '{print $3}')
fi

# Skip if installed >= latest (sort -V: lowest first, so tail-1 is the greater)
if [[ -n "$installed_version" ]] && \
   [[ "$(printf '%s\n' "$installed_version" "$latest_version" | sort -V | tail -1)" == "$installed_version" ]]; then
  echo "$NAME $installed_version is up to date, skipping."
  exit 0
fi

echo "Installing $NAME $latest to $DIR..."
rm -rf "$DIR"
git clone --quiet --depth=1 --branch="$latest" "$URL" "$DIR" >/dev/null

mkdir -p "$HOME/.local/bin"
chmod +x "$DIR/antidote"
ln -sfv "$DIR/antidote" "$HOME/.local/bin/antidote"
