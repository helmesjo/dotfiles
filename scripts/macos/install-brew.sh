#!/usr/bin/env bash
set -eu -o pipefail

if ! command -v brew &> /dev/null; then
  NONINTERACTIVE=1
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
brew update
