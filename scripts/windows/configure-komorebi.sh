#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

setx KOMOREBI_CONFIG_HOME "$(cygpath -m "$HOME/.config/komorebi")"
setx WHKD_CONFIG_HOME "$(cygpath -m "$HOME/.config/whkd")"

komorebic stop --whkd --bar
komorebic start --whkd --bar
