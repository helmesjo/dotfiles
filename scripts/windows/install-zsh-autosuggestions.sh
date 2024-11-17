#!/usr/bin/env bash

set -eu -o pipefail

mkdir -p "$HOME/.zsh"
rm -rf "$HOME/.zsh/zsh-autosuggestions"
command git clone --depth=1 --branch=v0.7.1 https://github.com/zsh-users/zsh-autosuggestions "$HOME/.zsh/zsh-autosuggestions"
