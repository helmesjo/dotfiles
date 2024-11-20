#!/usr/bin/env bash

set -eu -o pipefail

mkdir -p "$HOME/.zsh"
rm -rf "$HOME/.zsh/zsh-highlighting"
command git clone --depth=1 --branch=0.8.0 https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.zsh/zsh-syntax-highlighting"
