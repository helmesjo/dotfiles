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
  bat              # cat replacement
  eza              # ls replacement
  fish
  fzf
  ripgrep
  wl-clipboard     # system clipboard
  zoxide           # cd replacement
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
  udisks2          # Auto-mount removable devices
  udiskie          # udisks2 notifications
  waybar
  # Dev
  perf             # performance profiler
  git
  git-delta        # diff tool
  helix
  libsecret        # password storage
  nodejs
  python3
  vim
  ## Debugging
  lldb             # lldb-vscode
  ## Languge Server Protocol
  bash-language-server
  lua-language-server
  python-lsp-server
  yaml-language-server
  taplo-cli              # toml
  marksman               # markdown (code assist)
  # Misc
  firefox
)
aurpkgs=(
  # Core
  greetd
  tre-command      # nicer tree alternative
  # Hardware
  bluetuith        # bluetooth device tui
  ## Languge Server Protocol
  markdown-oxide   # markdown (lsp)
)

if [[ $is_wsl -eq 1 ]]; then
  # WSL requires compatible win32 clipboard.
  pacpkgs_rem=(wl-clipboard)
  wingetpkgs=(
    equalsraf.win32yank
  )
fi

if [[ $is_laptop -eq 1 ]]; then
  # power management
  pacpkgs+=(tlp)
fi

if command -v winget.exe >/dev/null 2>&1; then
  winget install --disable-interactivity \
                 --ignore-warnings \
                 --accept-source-agreements \
                 --accept-package-agreements \
                 ${wingetpkgs[@]} \
         || true
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
