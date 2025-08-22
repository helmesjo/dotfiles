#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

root_dir=`dirname $(readlink -f $BASH_SOURCE)`
os=$($root_dir/scripts/get-os.sh 2>&1)

echo "Setting up configuration for OS '$os'..."

if [[ $os == windows ]]; then
  export MSYS=winsymlinks:nativestrict
fi

# install packages for os
$root_dir/scripts/$os/install.sh
# configure os
$root_dir/scripts/configure.sh
