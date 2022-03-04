#
# ~/.bashrc
#

VISUAL=vim
EDITOR="$VISUAL"

# Path to file, or source if symlink.
dotfiles_root=`dirname $(realpath $BASH_SOURCE)`

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

# Aliases
alias config='/usr/bin/git -C $dotfiles_root'
