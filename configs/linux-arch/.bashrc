#
# ~/.bashrc
#

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export VISUAL=hx
export EDITOR="$VISUAL"
export COLORTERM=truecolor

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

function pathappend() {
  for arg in "$@"; do
    case ":$PATH:" in
      *":$arg:"*) ;;
      *) PATH="$PATH${PATH:+:}$arg" ;;
    esac
  done
}

pathappend "$HOME/.local/bin"
case "$(uname -s)" in
  Linux)
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
  MSYS*|MINGW*|CYGWIN)
    pathappend "$HOME/AppData/Local/Microsoft/WinGet/Links"
    pathappend "$HOME/AppData/Local/Microsoft/WindowsApps"
    pathappend "$(cygpath -u "$PROGRAMFILES/tre-command/bin")"
    pathappend "$(cygpath -u "$PROGRAMFILES/gsudo/Current")"
    pathappend "$(cygpath -u "$PROGRAMFILES/Git/mingw64/bin")"
    pathappend "$(cygpath -u "$PROGRAMFILES/LLVM/bin")"
    pathappend "$HOME/.cargo/bin"
    pathappend "/c/build2/bin"

    source "$HOME/.vsdevenv.sh"

    alias reboot='powershell.exe -command restart-computer'
    alias shutdown='powershell.exe -command stop-computer'
    ;;
esac

# alias for 'view in file manager' on various platforms
function _open_file_explorer() {
  local tgt_path="${1:-.}"
  if [[ ! -e "$tgt_path" ]]; then
    command $tgt_path
    return $?
  fi
  case "$(uname -s)" in
    Linux)
      xdg-open "$tgt_path" 2>/dev/null || gio open "$tgt_path" 2>/dev/null || nautilus "$tgt_path" 2>/dev/null
      ;;
    MINGW*|MSYS*|CYGWIN*)
      explorer "$(cygpath -w "$tgt_path")" >/dev/null 2>&1 & disown
      ;;
    *)
      echo "Unsupported platform: $(uname -s)" >&2
      return 1
      ;;
  esac
}

# completion function for _open_file_explorer
function _open_file_explorer_completion() {
  _files -/  # Completes files and directories
}

# NOTE: MacOS already has 'open' that does the right thing.
name=open
if ! command -v $name >/dev/null || [[ $(type -t $name) == "alias" ]]; then
  alias $name="_open_file_explorer"
  # Bind completion to the function and alias
  complete -F _open_file_explorer_completion _open_file_explorer
  complete -F _open_file_explorer_completion open
fi

# source aliases
source ~/.bazsh_aliases

eval "$(fzf --bash)"
# don't have ESC+c start fzf
bind '"\ec": nop'
eval "$(zoxide init bash --cmd cd)"
