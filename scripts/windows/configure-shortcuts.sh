#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

export MSYS=winsymlinks:nativestrict

this_dir=$(cygpath -u `dirname $(readlink -f $BASH_SOURCE)`)
root_dir=$(cygpath -u $(git -C "$(cygpath -m $this_dir)" rev-parse --show-toplevel))
os=$($root_dir/scripts/get-os.sh 2>&1)
dotfiles_root="$root_dir/configs/$os"
shortcuts_root="$dotfiles_root/.config/shortcuts"

# Copy each shortcut into Windows Start Menu directory
# so that they can be find through Windows Search
for sourcename in "$shortcuts_root"/*; do
  # get absolute path
  sourcename="${sourcename##*/}"
  sourcepath="$shortcuts_root/$sourcename"
  targetpath="$APPDATA/Microsoft/Windows/Start Menu/Programs/$sourcename"

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
