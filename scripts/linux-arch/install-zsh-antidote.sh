#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

URL="https://github.com/mattmc3/antidote"
NAME=$(basename $URL)
DIR="${ZDOTDIR:-$HOME}/.antidote"

# Fetch latest release tag from GitHub: vX.Y.Z
latest=$(curl -sf "https://api.github.com/repos/mattmc3/antidote/releases/latest" | \
  awk -F'"' '/"tag_name"/{print $4}')
latest_version="${latest#v}"

# Remove a leftover symlink from the old install method (upstream commit
# 94a8210 broke self-location through a symlink - see below), so it can't
# be left dangling by 'rm -rf "$DIR"' below and silently swallow the
# 'cat >' write to this same path further down.
if [[ -L "$HOME/.local/bin/antidote" ]]; then
  rm -f "$HOME/.local/bin/antidote"
fi

# Get currently installed version: 'antidote version X.Y.Z (abc1234)'
# If the version can't be determined, treat it as not installed.
installed_version=""
if command -v antidote >/dev/null 2>&1; then
  installed_version=$(antidote --version 2>/dev/null | awk '{print $3}') \
    || installed_version=""
fi

# Skip if installed >= latest (sort -V: lowest first, so tail-1 is the greater)
if [[ -n "$installed_version" ]] && \
   [[ "$(printf '%s\n' "$installed_version" "$latest_version" | sort -V | tail -1)" == "$installed_version" ]]; then
  echo "$NAME $installed_version is up to date, skipping."
  exit 0
fi

echo "Installing $NAME $latest to $DIR..."
rm -rf "$DIR"
git -c core.autocrlf=false -c advice.detachedHead=false -c core.hooksPath=/dev/null \
  clone --quiet --depth=1 --branch="$latest" "$URL" "$DIR" >/dev/null

mkdir -p "$HOME/.local/bin"
chmod +x "$DIR/antidote"
# Not a symlink to $DIR/antidote: that script finds its sibling
# antidote.zsh via zsh's ${0:...:h}, and upstream commit 94a8210
# deliberately switched that from ':A' (resolves symlinks) to ':a'
# (does not) for Homebrew's benefit - so invoking it through a symlink
# elsewhere no longer finds antidote.zsh at all. A wrapper that
# hardcodes the real path sidesteps self-location entirely.
cat > "$HOME/.local/bin/antidote" <<WRAPPER
#!/bin/zsh
source "$DIR/antidote.zsh"
antidote-dispatch "\$@"
WRAPPER
chmod +x "$HOME/.local/bin/antidote"
