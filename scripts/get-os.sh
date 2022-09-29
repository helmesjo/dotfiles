#!/usr/bin/env bash
set -eu -o pipefail

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  PAIR=$(cat /etc/*-release | grep "^DISTRIB_ID=" || true)
  PAIR=${PAIR:-$(cat /etc/*-release | grep "^ID=")}
  DISTRO=$(echo $PAIR | awk -F'=' '{print $2}' | tr '[:upper:]' '[:lower:]' | xargs)
  OS="linux-$DISTRO"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
elif [[ "$OSTYPE" == "cygwin" ]]; then
  OS="cygwin"
elif [[ "$OSTYPE" == "msys" ]]; then
  OS="mingw"
elif [[ "$OSTYPE" == "win32" ]]; then
  OS="windows"
elif [[ "$OSTYPE" == "freebsd"* ]]; then
  OS="freebsd"
else
  :
fi

echo "$OS" >&2
