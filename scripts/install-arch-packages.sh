#!/bin/bash
set -eu -o pipefail

echo "Installing required packages..."

pacpackages="mesa xorg vim git rxvt-unicode alsa-utils lightdm-gtk-greeter i3-gaps nitrogen rofi compton ttf-font-awesome adobe-source-code-pro-fonts ttf-nerd-fonts-symbols"
aurpackages="polybar"

# Install packages
sudo pacman -S --noconfirm $pacpackages
yay -S --noconfirm $aurpackages

# Build git-credential-libsecret
cd /usr/share/git/credential/libsecret && sudo make

