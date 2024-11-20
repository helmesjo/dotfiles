#!/usr/bin/env bash

set -eu -o pipefail

mkdir -p "$HOME/.zsh"
rm -rf "$HOME/.zsh/zsh-history-substring-search"
command git clone --depth=1 --branch=master https://github.com/zsh-users/zsh-history-substring-search "$HOME/.zsh/zsh-history-substring-search"
