#!/bin/bash

set -eu -o pipefail

dotfiles_root=`dirname $(realpath $BASH_SOURCE)`

$dotfiles_root/scripts/install.sh
$dotfiles_root/scripts/configure.sh
$dotfiles_root/scripts/configure-greetd.sh
$dotfiles_root/scripts/configure-nvim.sh

