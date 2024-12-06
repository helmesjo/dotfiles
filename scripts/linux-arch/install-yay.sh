#!/usr/bin/env bash

set -eu -o pipefail

URL="https://aur.archlinux.org/yay"
BRANCH=
NAME=$(basename $URL)
DIR="/tmp/build/$NAME"
echo "Installing $NAME $BRANCH to $DIR..."
if ! test -d $DIR || \
   ! command git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null; then
  mkdir -p "$DIR"
  git clone --quiet --depth=1 https://aur.archlinux.org/yay $DIR >/dev/null
  (cd $DIR && makepkg -Acs --noconfirm)
  sudo pacman -U --noconfirm $DIR/*.pkg.tar.zst
  rm -rf $DIR
fi
