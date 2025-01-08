#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

function on_error {
    echo "Failed..."
    exit 1
}
trap on_error ERR

root_dir=$(git rev-parse --show-toplevel)
os=$($root_dir/scripts/get-os.sh 2>&1)

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
