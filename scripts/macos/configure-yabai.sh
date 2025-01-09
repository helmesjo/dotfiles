#!/usr/bin/env bash
set -eu -o pipefail

# see: https://github.com/koekeishiya/yabai/wiki/Installing-yabai-(latest-release)#configure-scripting-addition

# yabai requires System Integrity Protection to be (partially) disabled
if ! csrutil status | grep disabled >/dev/null; then
  echo -e "yabai: system integrity protection needs to be (partially) disabled
  see: https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection#what-is-system-integrity-protection-and-why-does-it-need-to-be-disabled" \
  >&2
  exit 1
fi

# yabai uses the macOS Mach APIs to inject code into Dock.app;
# this requires elevated (root) privileges.
# configure user to execute yabai --load-sa as the root user
# without having to enter a password.
if ! test -f /private/etc/sudoers.d/yabai; then
  echo "yabai: set NOPASSWD for yabai"
  echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 $(which yabai) | cut -d " " -f 1) $(which yabai) --load-sa" \
       | sudo tee /private/etc/sudoers.d/yabai
fi

# for Apple Silicon; enable non-Apple-signed arm64e binaries
if ! nvram boot-args >/dev/null 2>&1; then
  printf '%s%b%s%b\n' "yabai: enable non-apple-signed arm64e binaries" $'\e[1;33m' " (REBOOT REQUIRED)" $'\e[1;0m'
  sudo nvram boot-args=-arm64e_preview_abi
fi

yabai --start-service
skhd --start-service
