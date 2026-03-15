#!/usr/bin/env bash
set -eu -o pipefail

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  source /etc/os-release 2>/dev/null || true
  DISTRO=$(echo ${ID_LIKE:-$ID} | tr '[:upper:]' '[:lower:]' | xargs)
  OS="linux-$DISTRO"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
elif [[ "$OSTYPE" == "cygwin" ]]; then
  OS="windows"
elif [[ "$OSTYPE" == "msys" ]]; then
  OS="windows"
elif [[ "$OSTYPE" == "win32" ]]; then
  OS="windows"
elif [[ "$OSTYPE" == "freebsd"* ]]; then
  OS="freebsd"
else
  :
fi

echo "$OS" >&2
