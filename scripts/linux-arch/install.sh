#!/usr/bin/env bash
set -eu -o pipefail

file_dir=`dirname $(readlink -f $BASH_SOURCE)`
$file_dir/install-zsh-pure.sh
$file_dir/install-zsh-autosuggestions.sh
$file_dir/install-zsh-syntax-highlighting.sh
$file_dir/install-zsh-history-substring-search.sh
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
  bemenu-wayland   # application runner
  bottom           # system monitor
  easyeffects      # audio controller
  gitui
  grim slurp       # screen grab tools
  mako             # notifications
  sway
  swaybg
  swayidle
  swaylock
  television       # multi-purpose fuzzy finder
  udisks2          # Auto-mount removable devices
  udiskie          # udisks2 notifications
  waybar
  yazi             # file manager
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
  # Misc
  firefox
)
aurpkgs=(
  # Core
  greetd
  tlrc-bin         # man
  # Hardware
  bluetuith        # bluetooth device tui
)

if [[ $is_wsl -eq 1 ]]; then
  # WSL requires win32-compatible clipboard,
  # so we replace wl-clipboard with win32yank.
  # See 'curl ...' after pacman install.
  pacpkgs_rem=(wl-clipboard)
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

if [[ $is_wsl -eq 1 ]]; then
  # download win32yank and place in PATH
  curl -sL https://github.com/equalsraf/win32yank/releases/download/v0.1.1/win32yank-x64.zip | \
    bsdtar -C ~/.local/bin/ -xz "win32yank.exe" && chmod +x ~/.local/bin/win32yank.exe
fi

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
