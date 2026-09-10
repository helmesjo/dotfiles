#
# ~/.bashrc
#

[[ -f "$HOME/.env" ]] && { set -a; source "$HOME/.env"; set +a; }

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Enable shared history
touch ~/.bash_history
chmod 600 ~/.bash_history
export HISTFILE=~/.bash_history
export HISTSIZE=1000
export HISTFILESIZE=2000
export HISTCONTROL=erasedups:ignorespace
export HISTTIMEFORMAT='%F %T '
shopt -s histappend

PS1='[\u@\h \W]> '

# source aliases
source ~/.bazsh_aliases

# Load drop-in configs
for f in ~/.bashrc.d/*.bash; do [[ -r "$f" ]] && source "$f"; done
