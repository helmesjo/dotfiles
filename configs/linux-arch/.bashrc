#
# ~/.bashrc
#

VISUAL=hx
EDITOR="$VISUAL"

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='[\u@\h \W]\$ '

# Aliases
source ~/.bazsh_aliases

# Path to file, or source if symlink.
# this_file=`dirname $(readlink -f $BASH_SOURCE)`
# dotfiles_root=$(git -C $this_file rev-parse --show-toplevel)

# Sourcing
if [[ "$OSTYPE" == "darwin"* ]]; then
  # fzf
  [ -f ~/.fzf.bash ] && source ~/.fzf.bash
else
  # fzf
  source /usr/share/fzf/key-bindings.bash
  source /usr/share/fzf/completion.bash
fi

# Export
export FZF_DEFAULT_COMMAND='rg --files --hidden'
export FZF_CTRL_T_COMMAND='$FZF_DEFAULT_COMMAND'
export FZF_COMPLETION_TRIGGER='??'

eval "$(zoxide init bash --cmd cd)"
