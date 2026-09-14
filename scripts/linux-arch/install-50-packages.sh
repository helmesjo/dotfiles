#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

is_laptop=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null | grep "\b9\b" > /dev/null && echo 1 || echo 0)
is_wsl=$([[ -n ${WSL_DISTRO_NAME:-} ]] && echo 1 || echo 0)

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
  noctalia         # desktop shell
  greetd           # greeter daemon
  noctalia-greeter # login greeter (CachyOS)
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
  # Shell dependencies
  accountsservice        # user account info (lock screen)
  xdg-desktop-portal-gtk # XDG portal backend (file picker, screen share)
)
aurpkgs=(
  # Core
  tlrc-bin         # man
  # Hardware
  bluetuith            # bluetooth TUI
  # Misc
  zen-browser-bin
  microsoft-edge-stable-bin
)

if [[ $is_wsl -eq 1 ]]; then
  # WSL requires win32-compatible clipboard, so wl-clipboard won't work and
  # win32yank is used instead (installed separately by install-win32yank.sh).
  # It's a Windows native executable that accesses the Win32 clipboard API,
  # so WSL interop runs it as a real Windows process, giving it access to
  # the shared Windows host clipboard.
  pacpkgs_rem=(cliphist wl-clipboard)
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
