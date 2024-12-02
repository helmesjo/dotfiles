#
# ~/.bashrc
#

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
VISUAL=hx
EDITOR="$VISUAL"

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='[\u@\h \W]\$ '

# Aliases
source ~/.bazsh_aliases

if [[ "$(uname -o)" =~ Msys|Cygwin ]]; then
    PATH="$PATH:~/AppData/Local/Microsoft/WinGet/Links"
    PATH="$PATH:~/AppData/Local/Microsoft/WindowsApps"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/tre-command/bin")"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/gsudo/Current")"
    PATH="$PATH:/c/build2/bin"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/Git/mingw64/bin")"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/LLVM/bin")"
    PATH="$PATH:~/.cargo/bin"

    alias sudo=gsudo

    source "$HOME/.vsdevenv.sh"
fi

eval "$(fzf --bash)"
eval "$(zoxide init bash --cmd cd)"
