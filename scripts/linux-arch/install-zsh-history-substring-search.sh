#!/usr/bin/env bash

set -eu -o pipefail

URL="https://github.com/zsh-users/zsh-history-substring-search"
BRANCH=master
NAME=$(basename $URL)
DIR="$HOME/.zsh/$NAME"
echo "Installing $NAME $BRANCH to $DIR..."
if ! test -d $DIR || \
   ! command git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null; then
  mkdir -p "$DIR"
  git clone --quiet --depth=1 --branch=$BRANCH $URL "$DIR" >/dev/null
fi
