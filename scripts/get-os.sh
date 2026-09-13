#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  source /etc/os-release 2>/dev/null || true
  DISTRO=$(echo ${ID_LIKE:-$ID} | tr '[:upper:]' '[:lower:]' | xargs)
  OS="linux-$DISTRO"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
elif [[ $OSTYPE =~ ^(cygwin|msys|win32) ]]; then
  OS="windows"
elif [[ "$OSTYPE" == "freebsd"* ]]; then
  OS="freebsd"
else
  :
fi

echo "$OS" >&2
