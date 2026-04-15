#
# ~/.zshrc
#

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export VISUAL=hx
export EDITOR="$VISUAL"
export COLORTERM=truecolor

# Enable shared history
touch ~/.zsh_history
chmod 600 ~/.zsh_history  # user-only read/write permission.
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt INC_APPEND_HISTORY_TIME # Add commands to history file immediately as they’re entered.
setopt HIST_EXPIRE_DUPS_FIRST  # Remove duplicate commands first when history size limit is reached.
setopt HIST_IGNORE_DUPS        # Don’t save consecutive duplicate commands in history.
setopt HIST_IGNORE_ALL_DUPS    # Remove all duplicates from history, even non-consecutive ones.
setopt HIST_IGNORE_SPACE       # Don’t save commands starting with a space in history.
setopt HIST_FIND_NO_DUPS       # Show only unique commands when searching history.
setopt HIST_SAVE_NO_DUPS       # Exclude duplicates when saving history to file.


setopt IGNORE_EOF   # don't kill session on Ctrl+D
setopt rmstarsilent # don't prompt [y/n] on rm -rf

# Bindings
bindkey '^[[1;3C' forward-word                   # alt+right
bindkey '^[[1;3D' backward-word                  # alt+left
bindkey '^[[3~'   delete-char                    # 'Del' key

# Shift+Enter: insert a literal newline into the ZLE buffer (no execute, no dquote prompt)
_zle_shift_enter() { LBUFFER+=$'\n' }
zle -N _zle_shift_enter
bindkey $'\e[13;2u' _zle_shift_enter
bindkey '\e^J' undefined-key  # disable built-in newline insertion on Alt+Enter (ESC+LF)
bindkey '\e^M' undefined-key  # same, covers both sequences terminals may send (ESC+CR)

# PATH setup
#
function pathappend() {
  for arg in "$@"; do
    case ":$PATH:" in
      *":$arg:"*) ;;
      *) PATH="$PATH${PATH:+:}$arg" ;;
    esac
  done
}

mkdir -p "$HOME/.local/bin"
pathappend "$HOME/.local/bin"
case "$(uname -s)" in
  Darwin)
    brew_path=$(brew --prefix)

    pathappend "$brew_path/bin"
    pathappend "$brew_path/opt/llvm/bin"

    (( ! ${fpath[(Ie)$brew_path/share/zsh-completions]} )) && \
      fpath+=($brew_path/share/zsh-completions)

    chmod -R go-w "$(brew --prefix)/share"

    unset brew_path
    ;;
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
      export command_not_found_handler() {
        local cmd="$1"
        shift
        # Skip if cmd is a shell function
        if [[ -n "$(typeset -f "$cmd" 2>/dev/null)" ]]; then
          return 127
        elif [[ -x "$(command -v "$cmd.exe")" ]]; then
          "$cmd.exe" "$@"
          return $?
        else
          echo "$cmd: command not found" >&2
          return 127
        fi
      }
      export which() {
        local cmds=()
        for cmd in "$@"; do
          # if not found in PATH, fall back to checking with .exe suffix.
          if ! (( ${+commands[$cmd]} )) && \
               (( ${+commands[$cmd.exe]} )); then
            cmd="$cmd.exe"
          fi
          cmds+=("$cmd")
        done
        command which ${cmds[@]}
      }
      # always reload hash (updates $commands list)
      hash -r

      # Rotate PATH so entries on mounted drives come after all non-mounted entries (order preserved)
      wsl_rotate_mounted_path_to_end() {
        local -a keep move
        local p

        for p in "${path[@]}"; do
          # Assume all single-letter mounted drives point to windows host
          if [[ $p == /mnt/[A-Za-z]/* ]]; then
            move+=("$p")
          else
            keep+=("$p")
          fi
        done

        path=("${keep[@]}" "${move[@]}")
      }
      wsl_rotate_mounted_path_to_end
      unset -f wsl_rotate_mounted_path_to_end
    fi
    ;;
  MSYS*|MINGW*|CYGWIN*)
    pathappend "$HOME/AppData/Local/Microsoft/WinGet/Links"
    pathappend "$HOME/AppData/Local/Microsoft/WindowsApps"
    pathappend "$(cygpath -u "$PROGRAMFILES/tre-command/bin")"
    pathappend "$(cygpath -u "$PROGRAMFILES/gsudo/Current")"
    pathappend "$(cygpath -u "$PROGRAMFILES/Git/mingw64/bin")"
    pathappend "$(cygpath -u "$PROGRAMFILES/LLVM/bin")"
    pathappend "/c/build2/bin"

    # forward certain envars to WSL
    export HOST___HOME="$HOME"
    export HOST___PROGRAMFILES="$PROGRAMFILES"
    export WSLENV=HOST___HOME/p:HOST___PROGRAMFILES/p

    # complete hard drives in msys2
    drives=$(mount | sed -rn 's#^[A-Z]: on /([a-z]).*#\1#p' | tr '\n' ' ')
    zstyle ':completion:*' fake-files /: "/:$drives"
    unset drives

    alias sudo=gsudo

    source "$HOME/.vsdevenv.sh"

    alias reboot='powershell.exe -command restart-computer'
    alias shutdown='powershell.exe -command stop-computer'
    ;;
esac

# custom prompt (single-line)
function prompt_pure_precmd() {
  local last_command_exit=$?
  local dir="%~"

  # git information
  vcs_info
  local git_info="${vcs_info_msg_0_:+$vcs_info_msg_0_ }"

  if [ $last_command_exit -ne 0 -a $last_command_exit -ne 145 ]; then
    # if the last command failed (and not from ctrl+z),
    # show the error code
    local error_code="%F{red}[$last_command_exit]%f "
  else
    local error_code=""
  fi

  # use pure's prompt_symbol configuration
  local prompt_symbol=${PURE_PROMPT_SYMBOL:-'>'}

  # set the prompt (single line)
  PROMPT="%F{blue}${dir}%f %F{magenta}${git_info}%f${error_code}${prompt_symbol} "

  # clear any existing right prompt
  RPROMPT=""
}
# unset before executing commands (but after rendered)
# to not pollute subprocesses (eg. cmd.exe)
# cmd.exe as a subprocess can't read zsh color markers %{%}
function prompt_pure_postprompt()
{
  unset -v PROMPT
}

# Plugins
if command -v antidote &>/dev/null; then
  if [[ -f ~/.zsh_plugins.txt ]]; then
    # Re-bundle when the plugin list changes or missing bundle.
    if [[ ( ! -f ~/.zsh_plugins.sh || \
            ~/.zsh_plugins.txt -nt ~/.zsh_plugins.sh ) \
       ]]; then
      antidote bundle < ~/.zsh_plugins.txt > ~/.zsh_plugins.sh
    fi

    # load plugins
    source ~/.zsh_plugins.sh
    eval "$(fzf --zsh)"

    # customize plugin behavior
    (( ${+functions[fast-theme]} )) && {
      FAST_HIGHLIGHT[use_async]=1
      FAST_HIGHLIGHT_STYLES[command]=none
      FAST_HIGHLIGHT_STYLES[precommand]=none
      FAST_HIGHLIGHT_STYLES[hashed-command]=none
      FAST_HIGHLIGHT[git-cmsg-len]=9999
    }
    (( ${+functions[_zsh_autosuggest_start]} )) && {
      ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    }
    (( ${+widgets[history-substring-search-up]} )) && {
      bindkey '^[[A' history-substring-search-up    # up arrow
      bindkey '^[[B' history-substring-search-down  # down arrow
    }
    (( ${+widgets[fzf-cd-widget]} )) && {
      bindkey -s '\ec' ''  # don't have ESC+c start fzf
    }

    # hook the custom precmd function
    add-zsh-hook precmd prompt_pure_precmd
    add-zsh-hook preexec prompt_pure_postprompt
  else
    echo "WARN: '~/.zsh_plugins.txt' missing" >&2
  fi
else
  echo "WARN: 'antidote' not found" >&2
fi

# load fpath completion functions
autoload -Uz bashcompinit compinit; bashcompinit; compinit

eval "$(zoxide init zsh --cmd cd)"

# ensure vcs_info is loaded for git status
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git*' formats "%b"

# see: .shell-aliases
# NOTE: MacOS already has 'open' that does the right thing.
name=open
if ! command -v $name >/dev/null || [[ "$(whence -w $name)" == *": alias" ]]; then
  alias $name="_open_file_explorer"
fi

# source aliases
source ~/.bazsh_aliases
[[ -f $HOME/.cargo/env ]] && source "$HOME/.cargo/env" || true
