#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR
unalias -a # disable aliases for script

setx KOMOREBI_CONFIG_HOME "$(cygpath -m "$HOME/.config/komorebi")"
setx WHKD_CONFIG_HOME "$(cygpath -m "$HOME/.config/whkd")"

komorebic stop --whkd --bar >/dev/null 2>&1 || true
komorebic start --whkd --bar
