#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

[[ -n ${WSL_DISTRO_NAME:-} ]] && exit 0

xdg-settings set default-web-browser browser-selector.desktop

echo "  - browser-selector is now the default browser."
