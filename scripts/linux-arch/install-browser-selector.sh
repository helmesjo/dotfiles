#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

[[ -n ${WSL_DISTRO_NAME:-} ]] && exit 0

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
