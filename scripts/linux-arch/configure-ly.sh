#!/bin/bash
set -eu -o pipefail

is_wsl=$([[ "$(uname -r)" == *WSL* ]] && echo 1 || echo 0 )

# Ly runs on tty2; disable getty on that tty to avoid conflict.
if [[ $is_wsl -eq 0 ]]; then
  sudo systemctl disable getty@tty2.service
fi
