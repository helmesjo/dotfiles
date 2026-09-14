#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

# None of the below applies to WSL: Wayland env vars are irrelevant without
# a native compositor, hardware groups (audio, bluetooth, etc.) are managed
# by the Windows host, and display manager / bluetooth services don't exist.
[[ -n ${WSL_DISTRO_NAME:-} ]] && exit 0

is_laptop=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null | grep "\b9\b" > /dev/null && echo 1 || echo 0)

# Setup system/package envars
envar_file="/etc/environment"
envars=(
  # Firefox
  MOZ_ENABLE_WAYLAND=1
  # Qt
  QT_QPA_PLATFORM=wayland
  QT_WAYLAND_DISABLE_WINDOWDECORATION=1
  QT_QPA_PLATFORMTHEME=qt6ct
)
echo "Setting up environment variables in '$envar_file'..."
for envar in ${envars[@]}; do
  echo "  - $envar"
  envar=($(echo $envar | tr "=" "\n"))
  if grep --quiet "${envar[0]}" $envar_file; then
    sudo sed -i "s/${envar[0]}=.*$/${envar[0]}=${envar[1]}/" $envar_file
  else
    echo "${envar[0]}=${envar[1]}" | sudo tee -a $envar_file
  fi
done

groups=(
  audio
  lp # external devices/bluetooth
  optical
  storage
  video
  wheel
)

services=(
  bluetooth.service
  greetd.service
)
user_services=()
if [ "$is_laptop" == "true" ]; then
  services+=(tlp.service)
fi

echo "Adding user '$(whoami)' to groups..."
for group in ${groups[@]}; do
  echo "  - $group"
  sudo usermod -aG $group $(whoami)
done

echo "Enabling services..."
for service in ${services[@]}; do
  echo "  - $service"
  sudo systemctl enable $service
done

for service in ${user_services[@]}; do
  echo "  - $service"
  systemctl --user enable $service
done

# Laptop only
if [ "$is_laptop" == "true" ]; then
  # tlp specific
  sudo systemctl mask systemd-rfkill.service
  sudo systemctl mask systemd-rfkill.socket
fi
