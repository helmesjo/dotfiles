#!/usr/bin/env bash

set -eu -o pipefail

mkdir -p "$HOME/.zsh"
rm -rf "$HOME/.zsh/pure"
command git clone --depth=1 --branch=v1.23.0 https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"
