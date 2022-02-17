#!/bin/bash

set -eu -o pipefail

dotfiles_root=`dirname $(realpath $BASH_SOURCE)`
enable_services="lightdm"

$dotfiles_root/scripts/install-arch-packages.sh
$dotfiles_root/scripts/configure.sh

# Enable services
for service in ${enable_services}; do
  sudo systemctl enable $service
done