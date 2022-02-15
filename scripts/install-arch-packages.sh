#!/bin/bash
set -eu -o pipefail

echo "Installing required packages..."

pacpackages="mesa xorg i3 lightdm-gtk-greeter pulseaudio-alsa noto-fonts noto-fonts-extra noto-fonts-emoji git kitty vim"
aurpackages="rlaunch siji-git polybar"

# Install packages
sudo pacman -S --noconfirm $pacpackages
yay -S --noconfirm $aurpackages

# Build git-credential-libsecret
cd /usr/share/git/credential/libsecret && sudo make

