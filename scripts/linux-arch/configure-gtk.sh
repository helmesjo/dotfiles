#!/bin/bash
set -eu -o pipefail

# Force GSettings/dconf to match adw-gtk3 so the XDG Desktop Portal 
# reports the correct theme to Wayland apps, overriding default Adwaita.
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
