#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

is_wsl=$([[ -n ${WSL_DISTRO_NAME:-} ]] && echo 1 || echo 0)

# greetd runs on tty1 and manages its own getty; no manual getty disable needed.
if [[ $is_wsl -eq 0 ]]; then
  sudo mkdir -p /etc/greetd
  sudo tee /etc/greetd/config.toml > /dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "noctalia-greeter"
user = "greeter"
EOF
fi
