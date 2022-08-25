#!/usr/bin/env bash
set -eu -o pipefail

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  DISTRO="$(lsb_release -a | awk -F':' '/Distributor ID/{print $2}' | awk '{$1=$1};1')"
  if [[ "$DISTRO" == "Arch"* ]]; then
    OS="linux-arch"
  fi  
  # ...
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