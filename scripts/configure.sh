#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

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
  if [[ -d "$targetpath" && ! -L "$targetpath"  ]]; then
    if ! mv -fv "$targetpath" "${targetpath}.$(date +%Y%m%d_%H%M%S).bak"; then
      echo "  - Warning: couldn't back up '$targetpath' (in use?) - skipping" >&2
      continue
    fi
  else
    if ! rm -fv "$targetpath"; then
      echo "  - Warning: couldn't remove '$targetpath' (in use?) - skipping" >&2
      continue
    fi
  fi
  printf "%s" "    - "
  while [[ -L "$sourcepath" ]]; do sourcepath=$(readlink -f "$sourcepath"); done
  ln -sv $sourcepath $targetpath
done

# On a clean host, ~/.profile didn't exist yet when this login shell started,
# so this process is still missing everything it appends to PATH (winget
# tools, ~/.local/bin, etc). The loop above may have just symlinked it into
# place for the first time - re-source it now so the configure-*.sh scripts
# below see the same PATH a normal new shell would.
[[ -f "$HOME/.profile" ]] && . "$HOME/.profile"

echo "Custom config..."

# os specific configuration
configs=$(ls $root_dir/scripts/$os | grep "configure-" --include .sh) # grab the list
for script in ${configs[@]}; do
  echo "  Running '$os/$script'..."
  $root_dir/scripts/$os/$script
done
