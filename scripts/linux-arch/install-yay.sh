#!/usr/bin/env bash

set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

if ! command -v yay >/dev/null 2>&1; then
  URL="https://aur.archlinux.org/yay-bin.git"
  BRANCH=
  NAME=$(basename $URL)
  DIR="$(mktemp -d)"

  sudo pacman -S --needed base-devel
  echo "Installing $NAME $BRANCH (temp dir: $DIR)..."
  sudo pacman -S --needed git base-devel
  git -c core.autocrlf=false -c advice.detachedHead=false clone --quiet --depth=1 $URL $DIR >/dev/null
  (cd $DIR && makepkg -sir --noconfirm)
  rm -rf $DIR
fi
