#
# ~/.bashrc
#

VISUAL=helix
EDITOR="$VISUAL"

# Path to file, or source if symlink.
dotfiles_root=`dirname $(realpath $BASH_SOURCE)`

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='[\u@\h \W]\$ '

# Aliases
alias cat='bat'
alias config='/usr/bin/git -C $dotfiles_root'
alias ls='ls --color=auto'

# Sourcing
source /usr/share/fzf/key-bindings.bash
source /usr/share/fzf/completion.bash

# Export
export FZF_DEFAULT_COMMAND='rg --files --hidden'
export FZF_CTRL_T_COMMAND='$FZF_DEFAULT_COMMAND'
export FZF_COMPLETION_TRIGGER='??'
