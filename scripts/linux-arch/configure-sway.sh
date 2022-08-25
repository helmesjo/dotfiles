#!/usr/bin/env bash
set -eu -o pipefail

if [ -v SWAYSOCK ]; then
  echo "Reload sway..."
  swaymsg reload
fi
