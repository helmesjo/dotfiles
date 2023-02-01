#!/bin/bash
set -eu -o pipefail

sudo sed -i "s/--cmd.*\"/--cmd sway\"/" /etc/greetd/config.toml
