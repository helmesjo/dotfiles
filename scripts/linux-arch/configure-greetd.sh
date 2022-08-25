#!/bin/bash
set -eu -o pipefail

sudo sed -i "s/--cmd \$SHELL/--cmd sway/" /etc/greetd/config.toml
