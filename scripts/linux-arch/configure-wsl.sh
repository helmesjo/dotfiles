#!/bin/bash
set -eu -o pipefail

is_wsl=$([[ "$(uname -r)" == *WSL* ]] && echo 1 || echo 0 )
this_dir=$(dirname $(readlink -f $BASH_SOURCE))

if [[ $is_wsl -eq 1 ]]; then
  printf "%s" "wsl: "
  sudo cp -v $this_dir/wsl.conf /etc/wsl.conf
  echo "  - Restart WSL for any changes to take effect."
fi
