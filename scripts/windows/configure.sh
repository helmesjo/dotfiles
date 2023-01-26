#!/usr/bin/env bash
set -eu -o pipefail

this_dir=`dirname $(readlink -f $BASH_SOURCE)`
root_dir=$(git -C $this_dir rev-parse --show-toplevel)
os=$($root_dir/scripts/get-os.sh 2>&1)
dotfiles_root="$root_dir/configs/$os/appdata"
dotfiles=$(ls -a $dotfiles_root) # grab the list
backup_nr=$(test -d $root_dir/_backup && find $root_dir/_backup/ -maxdepth 1 -type d -name '[0-9]*' | wc -l | xargs || echo 0)
dotfiles_backup="$root_dir/_backup/$backup_nr"
target_root="$APPDATA"
shortcuts_root="$dotfiles_root/shortcuts"
shortcuts=$(ls $shortcuts_root) # grab the list
echo "args: ${shortcuts[@]}"

#$this_dir/configure-fzf.sh

if [ "$os" == "windows" ]; then
  # https://github.com/git-for-windows/git/pull/156
  export MSYS=winsymlinks:nativestrict
fi

mkdir -p $dotfiles_backup
# Create a symlink ~/.config -> ~/AppData/Roaming
# so that we have the same structure as on unix.
# Backup target file/directory if it exists (-L to include broken symlinks)
if [ -e "$HOME/.config" ] || [ -L "$HOME/.config" ]; then
  echo "  - Backup '$HOME/.config'"
  printf "%s" "    - "
  mv -v "$HOME/.config" $dotfiles_backup/
fi
ln -sv "$HOME/AppData/Roaming" "$HOME/.config"

for sourcename in ${dotfiles[@]}; do
  # Filter out configs
  case $sourcename in
    "." | "..")
      continue
      ;;
    .git | .gitignore | .gitattributes)
      continue
      ;;
    *)
      ;;
  esac
  
  # get absolute path
  sourcepath=$(readlink -f "$dotfiles_root/$sourcename")
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
  fi

  echo "  - Creating symlink for '$sourcename'"
  printf "%s" "    - "
  ln -sv "$sourcepath" "$targetpath"
done

# Create a symlink for each shortcut into Windows Start Menu
# directory so that they can be find through Windows Search
for sourcename in ${shortcuts[@]}; do
  # get absolute path
  sourcepath="$shortcuts_root/$sourcename"
  targetpath="$ProgramData/Microsoft/Windows/Start Menu/Programs/$sourcename"

  [ -e "$sourcepath" ] || continue

  # Skip untracked files
  if [ -z "$(git -C $shortcuts_root ls-files $sourcename)" ]; then
    echo "  - Skipping untracked '$sourcename'"
    continue
  fi

  # Backup target file/directory if it exists (-L to include broken symlinks)
  if [ -e "$targetpath" ] || [ -L "$targetpath" ]; then
    echo "  - Backup '$targetpath'"
    printf "%s" "    - "
    mv -v "$targetpath" "$dotfiles_backup/"
  fi

  echo "  - Copying '$sourcename'"
  printf "%s" "    - "
  cp -fv "$sourcepath" "$targetpath"
done