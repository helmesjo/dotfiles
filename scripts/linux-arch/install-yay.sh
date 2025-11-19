#!/usr/bin/env bash

set -eu -o pipefail

URL="https://aur.archlinux.org/yay"
BRANCH=
NAME=$(basename $URL)
DIR="/tmp/build/$NAME"
if ! command -v yay >/dev/null 2>&1; then
  sudo pacman -S --needed base-devel
  echo "Installing $NAME $BRANCH to $DIR..."
  rm -rf "$DIR/"
  mkdir -p "$DIR"
  git clone --quiet --depth=1 https://aur.archlinux.org/yay $DIR >/dev/null
  (cd $DIR && makepkg -Acs --noconfirm)
  sudo pacman -U --noconfirm $DIR/*.pkg.tar.zst
  rm -rf $DIR
fi
