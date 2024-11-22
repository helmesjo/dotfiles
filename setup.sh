#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

dotfiles_root=`dirname $(readlink -f $BASH_SOURCE)`

os=$($dotfiles_root/scripts/get-os.sh 2>&1)

echo "Setting up configuration for OS '$os'..."

# install packages for os
$dotfiles_root/scripts/$os/install.sh
# symlink os-specific configs to home dir
(cd $dotfiles_root/configs/$os && $dotfiles_root/scripts/configure.sh)
