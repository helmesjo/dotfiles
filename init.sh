#!/bin/bash

dotfiles_root=`dirname $(realpath $BASH_SOURCE)`
dotfiles_backup="$dotfiles_root/backup"
target_root="$HOME"

dotfiles=($dotfiles_root/.[a-z,A-Z]*) # grab the list

echo "Configuring '$dotfiles_root' in '$target_root'..."
mkdir -p $dotfiles_backup
for sourcepath in ${dotfiles[@]}; do
  [ -e "$sourcepath" ] || continue

  sourcename=`basename $sourcepath`

  # Skip git-files
  if [[ $sourcename == .git* ]]; then
    echo "- Skipping '$sourcename'"
    continue
  fi

  # Skip untracked files  
  if [ -z "$(git -C $dotfiles_root ls-files $sourcepath)" ]; then
    echo "- Skipping untracked: '$sourcename'"
    continue
  fi

  targetpath="$target_root/$sourcename"

  # Backup target file if it exists
  if [ -f "$targetpath" ] || [ -d "$targetpath" ]; then
    echo "- Move backup '$targetpath' to '$dotfiles_backup'"
    mv $targetpath $dotfiles_backup/
  fi
  
  echo "- Creating symlink for '$sourcename'"
  printf "%s" " - "
  ln -sv $sourcepath $targetpath
#  ln -sfv $sourcepath $target_root/
done