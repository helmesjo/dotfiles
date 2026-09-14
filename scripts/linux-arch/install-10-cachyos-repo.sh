#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

# Skip if CachyOS repo is already configured.
grep -q '\[cachyos\]' /etc/pacman.conf && exit 0

mirror_url='https://mirror.cachyos.org/repo/x86_64/cachyos'

# The mirror only keeps the current build of each package (old ones get
# pruned, so a pinned version number eventually 404s) - resolve the current
# filename from the directory listing instead of hardcoding it.
latest_pkg() {
  curl -sf "$mirror_url/" \
    | grep -oE "href=\"$1-[0-9]+-[0-9]+-any\.pkg\.tar\.zst\"" \
    | sed -E 's/href="(.*)"/\1/' \
    | sort -V | tail -1
}

keyring_pkg=$(latest_pkg cachyos-keyring)
mirrorlist_pkg=$(latest_pkg cachyos-mirrorlist)

sudo pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key F3B607488DB35A47

sudo pacman -U --noconfirm \
  "$mirror_url/$keyring_pkg" \
  "$mirror_url/$mirrorlist_pkg"

sudo tee -a /etc/pacman.conf >/dev/null <<'EOF'

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOF
