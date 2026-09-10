#!/usr/bin/env bash
set -eu -o pipefail

[[ -n ${WSL_DISTRO_NAME:-} ]] && exit 0

xdg-settings set default-web-browser browser-selector.desktop

echo "  - browser-selector is now the default browser."
