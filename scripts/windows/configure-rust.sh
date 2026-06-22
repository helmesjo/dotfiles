#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

if [[ -z "$(command -v rustup 2>/dev/null || true)" ]]; then
  echo "WARN: rustup not found in PATH, nothing to configure"
  exit 0
fi

rustup set default-host x86_64-pc-windows-msvc
