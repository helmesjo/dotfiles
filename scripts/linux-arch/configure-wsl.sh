#!/bin/bash
set -eu -o pipefail

is_wsl=$([[ "$(uname -r)" == *WSL* ]] && echo 1 || echo 0 )
this_dir=$(dirname $(readlink -f $BASH_SOURCE))

if [[ $is_wsl -eq 1 ]]; then
  printf "%s" "wsl: "
  sudo cp -v $this_dir/wsl.conf /etc/wsl.conf

  # With systemd=true, systemd-binfmt.service registers Wine's binfmt handler
  # after WSL interop, which puts Wine at the head of the binfmt list and makes
  # it intercept all .exe execution. Mask it so WSL interop wins.
  # Wine can still be invoked explicitly as `wine foo.exe`.
  if [[ "$(readlink /etc/binfmt.d/wine.conf 2>/dev/null)" != "/dev/null" ]]; then
    sudo ln -sf /dev/null /etc/binfmt.d/wine.conf
    sudo systemctl restart systemd-binfmt
  fi

  echo "  - Restart WSL for any changes to take effect."
fi
