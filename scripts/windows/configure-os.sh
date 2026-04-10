#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

export MSYS=winsymlinks:nativestrict

this_dir=$(cygpath -u `dirname $(readlink -f $BASH_SOURCE)`)
root_dir=$(cygpath -u $(git -C "$(cygpath -m $this_dir)" rev-parse --show-toplevel))
os=$($root_dir/scripts/get-os.sh 2>&1)
dotfiles_root="$root_dir/configs/$os"
# grab the list (each in .config/*)
dotfiles=($(cd "$dotfiles_root" && find .config/ -maxdepth 1 -printf '%p '))

# first create a symlink ~/.config -> ~/AppData/Roaming,
# and ignore '.config' in loop below (we only want to
# iterate the files/folders in .config). this way when
# symlinked to ~/.config, they actually end up in AppData/Roaming.
if [[ -e $HOME/.config ]] || [[ -L $HOME/.config ]]; then
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
      continue ;;
    .config/)
      continue ;;
    .config/*)
      ;;
    *)
      echo "  - Skipping '$sourcename'"
      continue ;;
  esac

  # get absolute path
  sourcepath="$dotfiles_root/$sourcename"
  targetpath="$HOME/$sourcename"

  [[ -e "$sourcepath" ]] || ("  - Skipping missing '$sourcename'" && continue)

  # Skip untracked files
  if [[ -z "$(git -C $(cygpath -m "$dotfiles_root") ls-files $sourcename)" ]]; then
    echo "  - Skipping untracked '$sourcename'"
    continue
  fi
  
  echo "  - Creating symlink for '$sourcename'"
  printf "%s" "    - "
  if [[ -d "$targetpath" && ! -L "$targetpath"  ]]; then
    mv -fv "$targetpath" "${targetpath}.$(date +%Y%m%d_%H%M%S).bak"
  else
    rm -fv "$targetpath"
  fi
  printf "%s" "    - "
  ln -sv "$sourcepath" "$targetpath"
done
