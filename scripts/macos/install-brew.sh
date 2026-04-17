#!/usr/bin/env bash
set -eu -o pipefail

if ! command -v brew &> /dev/null; then
  NONINTERACTIVE=1
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Fix group/world-write permissions on brew's share dir.
  # zsh's compinit refuses to load completions from group-writable directories,
  # printing "insecure directories" warnings. Homebrew sometimes leaves g+w on
  # files there.
  chmod -R go-w "$(brew --prefix)/share"
fi
brew update
