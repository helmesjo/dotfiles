#!/usr/bin/env bash
set -eu -o pipefail

# Install win32yank.exe and a wrapper script that defaults to LF output.
# win32yank has no config file — the wrapper is the only way to set a default.
# Called from windows/install.sh.

URL="https://github.com/equalsraf/win32yank"
NAME=$(basename $URL)
BIN=~/.local/bin/win32yank.exe
VERSION_FILE=~/.local/bin/.win32yank-version

# Fetch latest release tag from GitHub: vX.Y.Z
latest=$(curl -sf "https://api.github.com/repos/equalsraf/win32yank/releases/latest" | \
  awk -F'"' '/"tag_name"/{print $4}')
latest_version="${latest#v}"

# Get currently installed version (stored in sidecar file on install)
installed_version=""
if [[ -f "$VERSION_FILE" ]]; then
  installed_version=$(cat "$VERSION_FILE")
fi

# Skip if installed >= latest (sort -V: lowest first, so tail -1 is the greater)
if [[ -n "$installed_version" ]] && \
   [[ "$(printf '%s\n' "$installed_version" "$latest_version" | sort -V | tail -1)" == "$installed_version" ]]; then
  echo "$NAME $installed_version is up to date, skipping."
  exit 0
fi

echo "Installing $NAME $latest to $(dirname $BIN)..."
mkdir -p ~/.local/bin

curl -sL "$URL/releases/download/$latest/win32yank-x64.zip" | \
  bsdtar -C ~/.local/bin/ -xz "win32yank.exe" && chmod +x "$BIN"

echo "$latest_version" > "$VERSION_FILE"

cat > ~/.local/bin/win32yank << 'EOF'
#!/usr/bin/env bash
exec win32yank.exe --lf "$@"
EOF
chmod +x ~/.local/bin/win32yank
