#!/usr/bin/env bash
set -eu -o pipefail

this_dir=$(dirname "$(readlink -f "$BASH_SOURCE")")
BROWSER_SELECTOR_SH="$this_dir/browser-selector.sh"
INSTALL_PATH="$HOME/.local/bin/browser-selector"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/browser-selector.desktop"

if [[ -f "$DESKTOP_FILE" ]]; then
    exit 0
fi

echo "Installing browser-selector..."

mkdir -p "$HOME/.local/bin" "$DESKTOP_DIR"
ln -sf "$BROWSER_SELECTOR_SH" "$INSTALL_PATH"

cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=BrowserSelector
Comment=Work/personal browser router
Exec=$INSTALL_PATH %u
Type=Application
NoDisplay=true
MimeType=x-scheme-handler/http;x-scheme-handler/https;
EOF

update-desktop-database "$DESKTOP_DIR"

echo "  - browser-selector installed to $INSTALL_PATH"
echo "  - browser-selector.desktop registered"
