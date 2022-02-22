#!/bin/bash
set -eu -o pipefail

this_file_path=$(dirname $(realpath $BASH_SOURCE))
dotfiles_root=$(cd $this_file_path/..; pwd)
dotfiles=$(ls -a $dotfiles_root) # grab the list
backup_nr=$(test -d $dotfiles_root/_backup && find $dotfiles_root/_backup/ -maxdepth 1 -type d -name '*' -printf x | wc -c || echo 1)
dotfiles_backup="$dotfiles_root/_backup/$backup_nr"
target_root="$HOME"

echo "Configuring '$dotfiles_root' in '$target_root'..."
mkdir -p $dotfiles_backup
for sourcename in ${dotfiles[@]}; do
  [ -e "$sourcename" ] || continue

  # Filter out configs
  case $sourcename in
    "." | "..")
      continue
      ;;
    .git*)
      continue
      ;;
    .[a-z,A-Z]*)
      ;;
    *)
      echo "  - Skipping '$sourcename'"
      continue
      ;;
  esac

  # Skip untracked files  
  if [ -z "$(git -C $dotfiles_root ls-files $sourcename)" ]; then
    echo "  - Skipping untracked '$sourcename'"
    continue
  fi

  sourcepath=$(realpath $sourcename)
  targetpath="$target_root/$sourcename"

  # Backup target file if it exists
  if [ -f "$targetpath" ] || [ -d "$targetpath" ]; then
    echo "  - Backup '$targetpath'"
    printf "%s" "    - "
    mv -v $targetpath $dotfiles_backup/
  fi
  
  echo "  - Creating symlink for '$sourcename'"
  printf "%s" "    - "
  ln -sv $sourcepath $targetpath
done

if command -v i3-msg &> /dev/null; then
  echo "Restart i3..."
  printf "%s" "  - "
  i3-msg restart
fi