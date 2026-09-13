#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR
unalias -a # disable aliases for script

if [[ -z "$(command -v rustup 2>/dev/null || true)" ]]; then
  echo "WARN: rustup not found in PATH, nothing to configure"
  exit 0
fi

rustup set default-host x86_64-pc-windows-msvc
