#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

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
