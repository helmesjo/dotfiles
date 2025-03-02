#
# ~/.bashrc
#

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
VISUAL=hx
EDITOR="$VISUAL"

# Enable shared history
touch ~/.bash_history
chmod 600 ~/.bash_history        # user-only read/write permission.
export HISTFILE=~/.bash_history  # History file location
export HISTSIZE=1000             # Maximum number of commands stored in memory.
export HISTFILESIZE=2000         # Maximum number of commands stored in the history file.
export HISTCONTROL=ignoredups    # Don’t save consecutive duplicate commands in history.
export HISTCONTROL=ignorespace   # Don’t save commands starting with a space in history (combine with ignoredups).
export HISTCONTROL=erasedups     # Remove all duplicates from history, even non-consecutive ones (combine with others).
export HISTTIMEFORMAT='%F %T '   # Save timestamp with each history entry (approximates INC_APPEND_HISTORY_TIME behavior).
shopt -s histappend              # Append new history entries to the file instead of overwriting it.

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='[\u@\h \W]\$ '

# Aliases
source ~/.bazsh_aliases

PATH="$PATH:$HOME/.local/bin"
case "$(uname -o)" in
  GNU/Linux)
    if [[ "$(uname -r)" == *WSL* ]]; then
      if ! test -f /mnt/c/Program\ Files/Git/mingw/bin/git-credential-manager.exe; then
        export GIT_CONFIG_COUNT=1
        export GIT_CONFIG_KEY_0=credential.helper
        export GIT_CONFIG_VALUE_0='/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe'
      fi
      # when running in wsl, override 'cmd not found' handler and
      # see if there is an .exe file available to avoid explicitly
      # spelling it out each time.
      function command_not_found_handle() {
        local cmd="$1"
        shift
        if [[ -x "$(command -v "$cmd.exe" 2>/dev/null)" ]]; then
          "$cmd.exe" "$@"
          return $?
        else
          echo "$cmd: command not found" >&2
          return 127
        fi
      }
      export -f command_not_found_handle
      function which() {
        local cmds=()
        for cmd in "$@"; do
          # if not found in PATH, fall back to checking with .exe suffix.
          if ! [[ -x "$(command -v "$cmd" 2>/dev/null)" ]] && \
               [[ -x "$(command -v "$cmd.exe" 2>/dev/null)" ]]; then
            cmd="$cmd.exe"
          fi
          cmds+=("$cmd")
        done
        command which ${cmds[@]}
      }
      export -f which
    fi
    ;;
  Msys|MINGW32|MINGW64)
    PATH="$PATH:$HOME/AppData/Local/Microsoft/WinGet/Links"
    PATH="$PATH:$HOME/AppData/Local/Microsoft/WindowsApps"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/tre-command/bin")"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/gsudo/Current")"
    PATH="$PATH:/c/build2/bin"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/Git/mingw64/bin")"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/LLVM/bin")"
    PATH="$PATH:$HOME/.cargo/bin"

    source "$HOME/.vsdevenv.sh"

    alias reboot='powershell.exe -command restart-computer'
    alias shutdown='powershell.exe -command stop-computer'
    ;;
esac

eval "$(fzf --bash)"
# don't have ESC+c start fzf
bind '"\ec": nop'
eval "$(zoxide init bash --cmd cd)"
