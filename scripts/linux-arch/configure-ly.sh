#!/bin/bash
set -eu -o pipefail

# Ly runs on tty2; disable getty on that tty to avoid conflict.
sudo systemctl disable getty@tty2.service
