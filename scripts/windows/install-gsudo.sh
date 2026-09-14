#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

if ! command -v gsudo &>/dev/null; then
  winget install --disable-interactivity \
                 --ignore-warnings \
                 --accept-source-agreements \
                 --accept-package-agreements \
                 gerardog.gsudo # sudo
fi
