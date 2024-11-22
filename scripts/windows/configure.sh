#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

# Symlinks for shortcuts requires elevated priviliges, so we ask once.
if [[ "$HOME" != $(cygpath -u "$USERPROFILE") ]] || ! net session > /dev/null 2>&1; then
  # Must run with correct home directory,
  # else it'll create it's own within msys2.
  MSYS=winsymlinks:nativestrict
  HOME=$(cygpath -u "$USERPROFILE")
  this_script="$(cygpath -u "$(readlink -f $BASH_SOURCE)")"

  echo "Re-running as admin with HOME=$HOME"
  "$(cygpath -u "$PROGRAMFILES/gsudo/Current/gsudo")" \
    bash -c "$this_script"
    exit $?
fi

this_dir=$(cygpath -m `dirname $(readlink -f $BASH_SOURCE)`)
root_dir=$(git -C "$this_dir" rev-parse --show-toplevel)
os=$($root_dir/scripts/get-os.sh 2>&1)
dotfiles_root="$root_dir/configs/$os"
dotfiles=($(find "$dotfiles_root" -mindepth 1 -maxdepth 2 -printf "%P ")) # grab the list
backup_nr=$(test -d $root_dir/_backup && find $root_dir/_backup/ -maxdepth 1 -type d -name '[0-9]*' | wc -l | xargs || echo 0)
dotfiles_backup="$root_dir/_backup/$backup_nr"
target_root="$HOME"
shortcuts_root="$dotfiles_root/.config/shortcuts"
shortcuts=$(ls $shortcuts_root) # grab the list

if [ "$os" == "windows" ]; then
  # https://github.com/git-for-windows/git/pull/156
  export MSYS=winsymlinks:nativestrict
fi

mkdir -p $dotfiles_backup

# first create a symlink ~/.config -> ~/AppData/Roaming,
# and ignore '.config' in loop below (we only want to
# iterate the files/folders in .config). this way when
# symlinked to ~/.config, they actually end up in AppData/Roaming.
if [ -e $target_root/.config ] || [ -L $target_root/.config ]; then
  echo "  - Backup '$target_root/.config'"
  printf "%s" "    "
  mv -v $target_root/.config $dotfiles_backup/
fi
ln -sv "$APPDATA/" "$target_root/.config"

for sourcename in ${dotfiles[@]}; do
  # Filter out configs
  case $sourcename in
    "." | "..")
      continue ;;
    .git | .gitignore | .gitattributes)
      continue
      ;;
    .config)
      continue ;;
    .[a-z,A-Z]*)
      ;;
    *)
      echo "  - Skipping '$sourcename'"
      continue ;;
  esac

  # get absolute path
  sourcepath=$(readlink -f "$dotfiles_root/$sourcename")
  targetpath="$target_root/$sourcename"
  
  [ -e "$sourcepath" ] || ("  - Skipping missing '$sourcename'" && continue)

  # Skip untracked files
  if [ -z "$(git -C $dotfiles_root ls-files $sourcename)" ]; then
    echo "  - Skipping untracked '$sourcename'"
    continue
  fi
  
  # Backup target file/directory if it exists (-L to include broken symlinks)
  if [ -e $targetpath ] || [ -L $targetpath ]; then
    echo "  - Backup '$targetpath'"
    printf "%s" "    "
    mv -v $targetpath $dotfiles_backup/
  fi

  echo "  - Creating symlink for '$sourcename'"
  printf "%s" "    "
  ln -sv "$sourcepath" "$targetpath"
done

# Create a symlink for each shortcut into Windows Start Menu
# directory so that they can be find through Windows Search
for sourcename in ${shortcuts[@]}; do
  # get absolute path
  sourcepath="$shortcuts_root/$sourcename"
  targetpath="$ProgramData/Microsoft/Windows/Start Menu/Programs/$sourcename"

  [ -e "$sourcepath" ] || ("  - Skipping missing '$sourcename'" && continue)

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
  "$(cygpath -u "$PROGRAMFILES/gsudo/Current/gsudo")" cp -fv "$sourcepath" "$targetpath"
done
