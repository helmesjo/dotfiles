#!/usr/bin/env bash
set -eu -o pipefail

file_dir=`dirname $(readlink -f $BASH_SOURCE)`
$file_dir/install-zsh-antidote.sh
$file_dir/install-yay.sh

is_laptop=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null | grep "\b9\b" > /dev/null && echo 1 || echo 0)
is_wsl=$([[ "$(uname -r)" == *WSL* ]] && echo 1 || echo 0 )

pacpkgs=(
  # Base
  bc
  glfw-wayland
  glibc-locales
  less
  libnotify
  lsb-release
  mesa
  net-tools
  pipewire-pulse
  qt5-wayland
  wayland
  wl-clipboard
  xorg-xlsclients
  xorg-xwayland
  # Core
  alacritty
  bat              # cat
  erdtree          # tree & ls
  fzf
  ripgrep
  zoxide           # cd
  # prompt
  zsh
  zsh-completions
  # Fonts
  noto-fonts-emoji
  ttf-jetbrains-mono-nerd
  # TUI/GUI
  bottom           # system monitor
  brightnessctl    # brightness control (shell dependency)
  cliphist         # clipboard history (shell launcher)
  easyeffects      # audio controller
  gitui
  grim slurp       # screen grab tools
  niri
  ly               # display manager
  wlsunset         # night light
  television       # multi-purpose fuzzy finder
  udisks2          # Auto-mount removable devices
  udiskie          # udisks2 notifications
  yazi             # file manager (TUI)
  pcmanfm          # file manager (GUI)
  # Dev
  perf             # performance profiler
  git
  git-delta        # diff tool
  helix
  libsecret        # credentials client
  gnome-keyring    # secret service provider
  nodejs
  python3
  vim
  lldb             # lldb-vscode
  ## Languge Server Protocol
  bash-language-server
  lua-language-server
  python-lsp-server
  yaml-language-server
  taplo-cli              # toml
  markdown-oxide         # markdown
  # Theming
  adw-gtk-theme          # gtk theme (shell dependency)
  nwg-look               # gtk settings tool
  qt5ct                  # qt theming tool (shell dependency)
  qt6ct                  # qt theming tool (shell dependency)
  # DMS dependencies
  accountsservice        # user account info (lock screen)
  xdg-desktop-portal-gtk # XDG portal backend (file picker, screen share)
)
aurpkgs=(
  # Core
  tlrc-bin         # man
  # DMS dependencies
  dms-shell-bin        # dank desktop shell
  quickshell           # compositor shell (DMS runtime)
  xwayland-satellite   # rootful XWayland for niri (DMS XWayland support)
  matugen              # material theme generator (DMS theming)
  dgop                 # on-screen display overlays (DMS OSD)
  # Hardware
  bluetuith            # bluetooth TUI
  # Misc
  zen-browser-bin
)

if [[ $is_wsl -eq 1 ]]; then
  # WSL requires win32-compatible clipboard, so wl-clipboard won't work and
  # win32yank is used instead. It's a Windows native executable that accesses
  # the Win32 clipboard API, so WSL interop runs it as a real Windows process,
  # giving it access to the shared Windows host clipboard.
  pacpkgs_rem=(cliphist wl-clipboard)
  $file_dir/install-win32yank.sh
fi

if [[ $is_laptop -eq 1 ]]; then
  # power management
  pacpkgs+=(tlp)
fi

# Install packages
sudo pacman -Sy --noconfirm archlinux-keyring && sudo pacman -Su --noconfirm
sudo pacman -Sy --needed --noconfirm "${pacpkgs[@]}"
yay -Sy --needed --noconfirm "${aurpkgs[@]}"

# Remove packages (if any)
[[ -n ${pacpkgs_rem:-} ]] && sudo pacman -R --noconfirm "${pacpkgs_rem[@]}"

# Remove unused (orphan) packages
pacman -Qtdq | sudo pacman -Rns --noconfirm - 2>/dev/null || true
yay -Yc --noconfirm

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
  ly@tty2.service
)
# Laptop only
if [ "$is_laptop" == "true" ]; then
  services+=(tlp.service)
fi

echo "Adding user '$(whoami)' to groups..."
for group in ${groups[@]}; do
  echo "  - $group"
  # printf "%s" "  - "
  sudo usermod -aG $group $(whoami)
done

echo "Enabling services..."
for service in ${services[@]}; do
  echo "  - $service"
  # printf "%s" "  - "
  sudo systemctl enable $service
done

# Laptop only
if [ "$is_laptop" == "true" ]; then
  # tlp specific
  sudo systemctl mask systemd-rfkill.service
  sudo systemctl mask systemd-rfkill.socket
fi
