#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

root_dir=`dirname $(readlink -f $BASH_SOURCE)`
os=$($root_dir/scripts/get-os.sh 2>&1)

echo "Setting up configuration for OS '$os'..."

if [[ $os == windows ]]; then
  source "$root_dir/scripts/windows/require-ucrt64.sh"
  export MSYS=winsymlinks:nativestrict
fi

# install packages for os
$root_dir/scripts/$os/install.sh
# configure os
$root_dir/scripts/configure.sh
