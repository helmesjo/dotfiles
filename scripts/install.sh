#!/bin/bash
set -eu -o pipefail

echo "Installing required packages..."

pacpackages="mesa xorg net-tools vim git gnome-keyring libsecret python3 firefox bc rxvt-unicode alsa-utils lightdm-gtk-greeter i3-gaps i3blocks nitrogen rofi compton ttf-font-awesome adobe-source-code-pro-fonts neovim nodejs ccls ctags"
#aurpackages=""

# Install yay if missing
if ! command -v yay &> /dev/null; then
  git clone https://aur.archlinux.org/yay $HOME/git/yay
  (cd $HOME/git/yay && makepkg -Acs --noconfirm)
  sudo pacman -U --noconfirm $HOME/git/yay/*.pkg.tar.zst
  rm -rf $HOME/git
fi

# Install packages
sudo pacman -S --noconfirm $pacpackages
#yay -S --noconfirm $aurpackages

