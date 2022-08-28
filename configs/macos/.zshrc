#
# ~/.zshrc
#

VISUAL=hx
EDITOR="$VISUAL"

# Aliases
source ~/.bazsh_aliases

# Sourcing
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Export
export FZF_DEFAULT_COMMAND='rg --files --hidden'
export FZF_CTRL_T_COMMAND='$FZF_DEFAULT_COMMAND'
export FZF_COMPLETION_TRIGGER='??'
