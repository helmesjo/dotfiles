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

if [[ $OSTYPE == 'msys' ]]; then
    PATH="$PATH:~/AppData/Local/Microsoft/WinGet/Links"
    PATH="$PATH:~/AppData/Local/Microsoft/WindowsApps"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/tre-command/bin")"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/gsudo/Current")"
    PATH="$PATH:/c/build2/bin"

    alias sudo=gsudo
fi

eval "$(fzf --bash)"
eval "$(zoxide init bash --cmd cd)"
