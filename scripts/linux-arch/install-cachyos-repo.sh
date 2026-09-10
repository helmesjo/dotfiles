#!/usr/bin/env bash
set -eu -o pipefail

# Skip if CachyOS repo is already configured.
grep -q '\[cachyos\]' /etc/pacman.conf && exit 0

pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47

pacman -U --noconfirm \
  'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
  'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-18-1-any.pkg.tar.zst'

cat >> /etc/pacman.conf <<'EOF'

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOF
