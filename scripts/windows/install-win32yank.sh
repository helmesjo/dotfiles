#!/usr/bin/env bash
set -eu -o pipefail

# Install win32yank.exe and a wrapper script that defaults to LF output.
# win32yank has no config file so the wrapper is the only way to set a default.

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

# Skip if installed >= latest AND the binary is a real PE executable (not a stale shell script)
if [[ -n "$installed_version" ]] && \
   [[ "$(printf '%s\n' "$installed_version" "$latest_version" | sort -V | tail -1)" == "$installed_version" ]] && \
   file "$BIN" 2>/dev/null | grep -q "PE32"; then
  echo "  - $NAME $installed_version is up to date, skipping (installed=$installed_version >= latest=$latest_version)."
  exit 0
fi

echo "Installing $NAME $latest to $(dirname $BIN)..."
mkdir -p ~/.local/bin

# Remove the binary first: MSYS2 applies PATHEXT resolution on writes, so
# `cat > .../win32yank` silently redirects to win32yank.exe when it exists.
rm -f "$BIN"

WRAPPER="${BIN%.*}"
cat > "$WRAPPER" << 'EOF'
#!/usr/bin/env bash
exec "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/win32yank.exe" --lf "$@"
EOF
chmod +x "$WRAPPER"

curl -L# "$URL/releases/download/$latest/win32yank-x64.zip" | \
  bsdtar -C ~/.local/bin/ -xz "win32yank.exe" && chmod +x "$BIN"

if ! file "$BIN" | grep -q "PE32"; then
  echo "error: $BIN is not a valid Windows executable — download may have failed" >&2
  rm -f "$BIN"
  exit 1
fi

echo "$latest_version" > "$VERSION_FILE"
