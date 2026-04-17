#
# ~/.bashrc
#

[[ -f "$HOME/.env" ]] && { set -a; source "$HOME/.env"; set +a; }

# Enable shared history
touch ~/.bash_history
chmod 600 ~/.bash_history        # user-only read/write permission.
export HISTFILE=~/.bash_history  # History file location
export HISTSIZE=1000             # Maximum number of commands stored in memory.
export HISTFILESIZE=2000         # Maximum number of commands stored in the history file.
export HISTCONTROL=ignoredups    # Don't save consecutive duplicate commands in history.
export HISTCONTROL=ignorespace   # Don't save commands starting with a space in history (combine with ignoredups).
export HISTCONTROL=erasedups     # Remove all duplicates from history, even non-consecutive ones (combine with others).
export HISTTIMEFORMAT='%F %T '   # Save timestamp with each history entry (approximates INC_APPEND_HISTORY_TIME behavior).
shopt -s histappend              # Append new history entries to the file instead of overwriting it.

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='[\u@\h \W]> '

# platform-specific setup
case "$(uname -s)" in
  Linux)
    if [[ "$(uname -r)" == *WSL* ]]; then
      # use windows git-credential-manager in WSL to avoid re-authenticating
      if test -f "$HOST___PROGRAMFILES/Git/mingw64/bin/git-credential-manager.exe"; then
        ! command -v git-credential-manager.exe >/dev/null && \
          rm -f ~/.local/bin/git-credential-manager.exe && \
          ln -sv "$HOST___PROGRAMFILES/Git/mingw64/bin/git-credential-manager.exe" ~/.local/bin
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

      # always reload hash (updates $commands list)
      hash -r
    fi
    ;;
  MSYS*|MINGW*|CYGWIN)
    alias reboot='powershell.exe -command restart-computer'
    alias shutdown='powershell.exe -command stop-computer'

    source "$HOME/.vsdevenv.sh"
    ;;
esac

# see: .shell-aliases
# NOTE: MacOS already has 'open' that does the right thing.
name=open
if ! command -v $name >/dev/null || [[ $(type -t $name) == "alias" ]]; then
  alias $name="_open_file_explorer"
fi

# source aliases
source ~/.bazsh_aliases

# Load drop-in configs
for f in ~/.bashrc.d/*.bash; do [[ -r "$f" ]] && source "$f"; done
