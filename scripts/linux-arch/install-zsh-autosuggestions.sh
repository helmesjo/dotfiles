#!/usr/bin/env bash

set -eu -o pipefail

URL="https://github.com/zsh-users/zsh-autosuggestions"
BRANCH=v0.7.1
NAME=$(basename $URL)
DIR="$HOME/.zsh/$NAME"
if ! test -d $DIR || \
   ! command git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null; then
  echo "Installing $NAME $BRANCH to $DIR..."
  mkdir -p "$DIR"
  git clone --quiet --depth=1 --branch=$BRANCH $URL "$DIR" >/dev/null
fi
