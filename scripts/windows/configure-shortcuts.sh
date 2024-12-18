#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

export MSYS=winsymlinks:nativestrict

# Symlinks for shortcuts requires elevated privileges.
if ! net session > /dev/null 2>&1; then
  echo "Re-run as admin" >&2
  exit 1
fi

this_dir=$(cygpath -u `dirname $(readlink -f $BASH_SOURCE)`)
root_dir=$(cygpath -u $(git -C "$(cygpath -m $this_dir)" rev-parse --show-toplevel))
os=$($root_dir/scripts/get-os.sh 2>&1)
dotfiles_root="$root_dir/configs/$os"
shortcuts_root="$dotfiles_root/.config/shortcuts"
shortcuts=$(ls $shortcuts_root) # grab the list

# Copy each shortcut into Windows Start Menu directory
# so that they can be find through Windows Search
for sourcename in ${shortcuts[@]}; do
  # get absolute path
  sourcepath="$shortcuts_root/$sourcename"
  targetpath="$ProgramData/Microsoft/Windows/Start Menu/Programs/$sourcename"

  # Skip untracked files
  if [ -z "$(git -C "$(cygpath -m $shortcuts_root)" ls-files $sourcename)" ]; then
    echo "  - Skipping untracked '$sourcename'"
    continue
  fi

  echo "  - Copying '$sourcename'"
  printf "%s" "    - "
  rm -fv "$targetpath"
  printf "%s" "    - "
  cp -fv "$sourcepath" "$targetpath"
done
