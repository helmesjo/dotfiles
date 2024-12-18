#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

function on_error {
    echo "Failed..."
    exit 1
}
trap on_error ERR

# this_dir=$(dirname $(readlink -f $BASH_SOURCE))
root_dir=$(git rev-parse --show-toplevel)
os=$($root_dir/scripts/get-os.sh 2>&1)

# Windows reguires elevated privileges for shortcuts, reg import etc , so we ask once.
# Also make sure HOME points to the current users home directory.
if [[ $os == 'windows' ]]; then
  if [[ "$HOME" != $(cygpath -u "$USERPROFILE") ]] || ! net session > /dev/null 2>&1; then
    # Must run with correct home directory,
    # else it'll create it's own within msys2.
    export MSYS=winsymlinks:nativestrict
    export HOME=$(cygpath -u "$USERPROFILE")
    this_script="$(cygpath -u "$(readlink -f $BASH_SOURCE)")"

    echo "Re-running as admin with HOME=$HOME"
    "$(cygpath -u "$PROGRAMFILES/gsudo/Current/gsudo")" \
      bash -c "$this_script"
      exit $?
  fi
fi

dotfiles_root=$root_dir/configs/$os
dotfiles=$(ls -a $dotfiles_root) # grab the list

# Setup dotfiles
echo "Configuring '$dotfiles_root' in '$HOME'..."

for sourcename in ${dotfiles[@]}; do
  # Filter out configs
  case $sourcename in
    "." | "..")
      continue
      ;;
    .git | .gitignore | .gitattributes)
      continue
      ;;
    .[a-z,A-Z]*)
      ;;
    *)
      echo "  - Skipping '$sourcename'"
      continue
      ;;
  esac

  # get absolute path
  sourcepath=$dotfiles_root/$sourcename
  targetpath="$HOME/$sourcename"

  # Skip untracked files
  if [ -z "$(git -C $dotfiles_root ls-files $sourcename)" ]; then
    echo "  - Skipping untracked '$sourcename'"
    continue
  fi
  
  echo "  - Creating symlink for '$sourcename'"
  printf "%s" "    - "
  rm -fv "$targetpath"
  printf "%s" "    - "
  ln -sv $sourcepath $targetpath
done

echo "Custom config..."

# os specific configuration
configs=$(ls $root_dir/scripts/$os | grep "configure-" --include .sh) # grab the list
for script in ${configs[@]}; do
  echo "  - Running '$os/$script'..."
  $root_dir/scripts/$os/$script
done
