#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR
unalias -a # disable aliases for script

export MSYS=winsymlinks:nativestrict

this_dir=$(cygpath -u `dirname $(readlink -f $BASH_SOURCE)`)
root_dir=$(cygpath -u $(git -C "$(cygpath -m $this_dir)" rev-parse --show-toplevel))
os=$($root_dir/scripts/get-os.sh 2>&1)
dotfiles_root="$root_dir/configs/$os"
startup_root="$dotfiles_root/.config/startup"

# Copy each shortcut into Windows Startup directory
# so that they autostart upon login.
for sourcename in "$startup_root"/*; do
  # get absolute path
  sourcename="${sourcename##*/}"
  sourcepath="$startup_root/$sourcename"
  targetpath="$APPDATA/Microsoft/Windows/Start Menu/Programs/Startup/$sourcename"

  # Skip untracked files
  if [ -z "$(git -C "$(cygpath -m $startup_root)" ls-files "$sourcename")" ]; then
    echo "  - Skipping untracked '$sourcename'"
    continue
  fi

  echo "  - Copying '$sourcename'"
  printf "%s" "    - "
  rm -fv "$targetpath"
  printf "%s" "    - "
  cp -fv "$sourcepath" "$targetpath"
done
