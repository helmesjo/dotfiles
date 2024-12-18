#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

export MSYS=winsymlinks:nativestrict

this_dir=$(cygpath -u `dirname $(readlink -f $BASH_SOURCE)`)
root_dir=$(cygpath -u $(git -C "$(cygpath -m $this_dir)" rev-parse --show-toplevel))
os=$($root_dir/scripts/get-os.sh 2>&1)
dotfiles_root="$root_dir/configs/$os"
dotfiles=($(find "$dotfiles_root" -mindepth 1 -maxdepth 2 -printf "%P ")) # grab the list

# first create a symlink ~/.config -> ~/AppData/Roaming,
# and ignore '.config' in loop below (we only want to
# iterate the files/folders in .config). this way when
# symlinked to ~/.config, they actually end up in AppData/Roaming.
if [ -e $HOME/.config ] || [ -L $HOME/.config ]; then
  echo "  - Remove '$HOME/.config'"
  printf "%s" "    - "
  rm -v $HOME/.config
fi
echo "  - Creating symlink for '$HOME/.config'"
printf "%s" "    "
ln -sv "$APPDATA/" "$HOME/.config"

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
  sourcepath="$dotfiles_root/$sourcename"
  targetpath="$HOME/$sourcename"
  
  [ -e "$sourcepath" ] || ("  - Skipping missing '$sourcename'" && continue)

  # Skip untracked files
  if [ -z "$(git -C $(cygpath -m "$dotfiles_root") ls-files $sourcename)" ]; then
    echo "  - Skipping untracked '$sourcename'"
    continue
  fi
  
  # if target is a non-symlink directory then only remove the files
  # we will overwrite (in case the target directory contains a bunch of
  # files created/used by other software).
  if [ -d $targetpath ] && [ ! -L $targetpath ]; then
    sourcefiles=($(cd $sourcepath && find . -type f))
    for file in ${sourcefiles[@]}; do
      sourcefile="$sourcepath/$file"
      targetfile="$targetpath/$file"

      echo "  - Creating symlink for file '$sourcefile'"
      printf "%s" "    - "
      rm -fv "$targetfile"
      printf "%s" "    - "
      ln -sv "$sourcefile" "$targetfile"
    done
  else
    echo "  - Creating symlink for target '$sourcepath'"
    printf "%s" "    - "
    rm -fv "$targetpath"
    printf "%s" "    - "
    ln -sv "$sourcepath" "$targetpath"
  fi
done
