#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

this_dir=$(dirname $(readlink -f $BASH_SOURCE))
root_dir=$(git -C "$this_dir" rev-parse --show-toplevel)
os=$($root_dir/scripts/get-os.sh 2>&1)
dotfiles_root="$root_dir/configs/$os"

# antidote clones plugin repos internally, outside our control - disable
# hooks via env vars (rather than a git -c flag) so the setting reaches
# those clones too, not just a git command we invoke directly.
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null

$HOME/.local/bin/antidote bundle < "$dotfiles_root/.zsh_plugins.txt" > ~/.zsh_plugins.sh
