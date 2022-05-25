#!/bin/bash
set -eu -o pipefail

echo "Installing required packages..."

pacpkgs=(
  # Base
  net-tools
  libnotify
  mesa
  wayland
  wl-clipboard
  qt5-wayland
  glfw-wayland
  xorg-xwayland
  xorg-xlsclients
  pulseaudio
  pavucontrol
  firefox
  bc
  ttf-font-awesome
  adobe-source-code-pro-fonts
  # Core
  alacritty
  bat
  fish
  fzf
  ripgrep
  # TUI/GUI
  bemenu-wayland   # application runner
  bottom           # system monitor
  mako             # notifications
  sway
  swayidle
  swaylock
  waybar
  # Dev
  git
  git-delta
  gnome-keyring
  helix
  libsecret
  neovim
  nodejs
  python3
  vim
)
aurpkgs=(
  greetd
)

# Install yay if missing
if ! command -v yay &> /dev/null; then
  git clone https://aur.archlinux.org/yay $HOME/git/yay
  (cd $HOME/git/yay && makepkg -Acs --noconfirm)
  sudo pacman -U --noconfirm $HOME/git/yay/*.pkg.tar.zst
  rm -rf $HOME/git
fi

# Install packages
sudo pacman -Sy --needed --noconfirm "${pacpkgs[@]}"
yay -Sy --needed --noconfirm "${aurpkgs[@]}"

# Setup system/package envars
envar_file="/etc/environment"
envars=(
  # Firefox
  MOZ_ENABLE_WAYLAND=1
  # Qt
  QT_WAYLAND_DISABLE_WINDOWDECORATION=1
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

services=(
  greetd
)
echo "Enabling services..."
for service in ${services[@]}; do
  echo "  - $service"
  printf "%s" "  - "
  sudo systemctl enable $service
done

