#!/usr/bin/env bash
set -eu -o pipefail

this_file=`dirname $(readlink -f $BASH_SOURCE)`
root_dir=$(git -C $this_file rev-parse --show-toplevel)
os=$($root_dir/scripts/get-os.sh 2>&1)
dotfiles_root=$root_dir/configs/$os
dotfiles=$(ls -a $dotfiles_root) # grab the list
backup_nr=$(test -d $root_dir/_backup && find $root_dir/_backup/ -maxdepth 1 -type d -name '[0-9]*' | wc -l | xargs || echo 0)
dotfiles_backup="$root_dir/_backup/$backup_nr"
target_root="$HOME"

# Setup dotfiles
echo "Configuring '$dotfiles_root' in '$target_root'..."

mkdir -p $dotfiles_backup
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
  # sourcepath=$(readlink -f $sourcename) # unsure why this was required...
  targetpath="$target_root/$sourcename"
  
  [ -e "$sourcepath" ] || continue

  # Skip untracked files
  if [ -z "$(git -C $dotfiles_root ls-files $sourcename)" ]; then
    echo "  - Skipping untracked '$sourcename'"
    continue
  fi
  
  # Backup target file/directory if it exists (-L to include broken symlinks)
  if [ -e $targetpath ] || [ -L $targetpath ]; then
    echo "  - Backup '$targetpath'"
    printf "%s" "    - "
    mv -v $targetpath $dotfiles_backup/
  else
    echo "  - '$targetpath' does not exist"
  fi

  echo "  - Creating symlink for '$sourcename'"
  printf "%s" "    - "
  ln -sv $sourcepath $targetpath
done

echo "Custom config..."

# os specific configuration
configs=$(ls $root_dir/scripts/$os | grep "configure-" --include .sh) # grab the list
for script in ${configs[@]}; do
  echo "  - Running '$script'..."
  $root_dir/scripts/$os/$script
done

