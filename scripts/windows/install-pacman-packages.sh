#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

pacmanpkgs=(
  zsh
  mingw-w64-ucrt-x86_64-gcc
)

# Run a command in a new mintty window and wait for it to finish.
# mintty --hold never closes the window immediately on exit so the
# wait below can detect completion rather than hanging indefinitely.
function run_in_mintty {
  mintty --hold never -e bash -lc "$*" &
  wait $! || true
}

# Upgrading msys2-runtime terminates the running shell mid-upgrade, so a
# second pass is required to finish. Check before starting so we only pay
# the cost when the runtime actually needs upgrading.
if pacman -Qu 2>/dev/null | grep -q '^msys2-runtime '; then
  run_in_mintty 'pacman --noconfirm -Syu'
fi

pacman --noconfirm --needed -Syu ${pacmanpkgs[*]}
