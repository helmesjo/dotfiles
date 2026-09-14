#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

root_dir=$(git rev-parse --show-toplevel)
os=$($root_dir/scripts/get-os.sh 2>&1)

if [[ $os == windows ]]; then
  source "$root_dir/scripts/windows/require-ucrt64.sh"
fi

# os specific installs
installs=$(ls $root_dir/scripts/$os | grep "install-" --include .sh) # grab the list
for script in ${installs[@]}; do
  name="${script#install-}"
  name="${name%.sh}"
  echo "==> Installing $name..."
  $root_dir/scripts/$os/$script
done
