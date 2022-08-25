#!/usr/bin/env bash
set -eu -o pipefail

dotfiles_root=`dirname $(readlink -f $BASH_SOURCE)`

os=$($dotfiles_root/scripts/get-os.sh 2>&1)

echo "Setting up configuration for OS '$os'..."

# install packages for os
$dotfiles_root/scripts/$os/install.sh
# symlink os-specific configs to home dir
(cd $dotfiles_root/configs/$os && $dotfiles_root/scripts/configure.sh)

echo "Custom config..."

# os specific configuration
configs=$(ls $dotfiles_root/scripts/$os | grep "configure-" --include .sh) # grab the list
for script in ${configs[@]}; do
  echo "  - Running '$script'..."
  $dotfiles_root/scripts/$os/$script
done
