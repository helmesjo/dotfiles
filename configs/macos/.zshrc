#
# ~/.zshrc
#

VISUAL=hx
EDITOR="$VISUAL"

# Aliases
source ~/.bazsh_aliases

# Sourcing
source ~/.config/fzf/key-bindings.bash
source ~/.config/fzf/completion.bash

# Export
export FZF_DEFAULT_COMMAND='rg --files --hidden'
export FZF_CTRL_T_COMMAND='$FZF_DEFAULT_COMMAND'
export FZF_COMPLETION_TRIGGER='??'
export LC_ALL=en_US.UTF-8