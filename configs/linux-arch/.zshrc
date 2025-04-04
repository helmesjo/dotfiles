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

# fpaths
(( ! ${fpath[(Ie)$HOME/.zsh/pure]} )) && fpath+=($HOME/.zsh/pure)

# Plugins
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.zsh/zsh-history-substring-search/zsh-history-substring-search.zsh

# Bindings
bindkey '^[[A'    history-substring-search-up    # arrow-up
bindkey '^[[B'    history-substring-search-down  # arrow-down
bindkey '^[[1;3C' forward-word                   # alt+right
bindkey '^[[1;3D' backward-word                  # alt+left
bindkey '^[[3~'   delete-char

# Aliases
source ~/.bazsh_aliases

PATH="$PATH:$HOME/.local/bin"
case "$(uname -o)" in
  Darwin)
    brew_path=$(brew --prefix)

    (( ! ${PATH[(Ie)$brew_path/bin]} )) && \
      PATH="${PATH:+${PATH}:}$brew_path/bin"

    (( ! ${PATH[(Ie)$brew_path/opt/llvm/bin]} )) && \
      PATH="${PATH:+${PATH}:}$brew_path/opt/llvm/bin"

    (( ! ${fpath[(Ie)$brew_path/share/zsh-completions]} )) && \
      fpath+=($brew_path/share/zsh-completions)

    chmod -R go-w "$(brew --prefix)/share"
    autoload -U promptinit; promptinit
    prompt pure

    unset brew_path
    ;;
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
      export command_not_found_handler() {
        local cmd="$1"
        shift
        if [[ -x "$(command -v "$cmd.exe")" ]]; then
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
               ((  ${+commands[$cmd.exe]} )); then
            cmd="$cmd.exe"
          fi
          cmds+=("$cmd")
        done
        command which ${cmds[@]}
      }
    fi
    autoload -U promptinit; promptinit
    prompt pure
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

    # complete hard drives in msys2
    drives=$(mount | sed -rn 's#^[A-Z]: on /([a-z]).*#\1#p' | tr '\n' ' ')
    zstyle ':completion:*' fake-files /: "/:$drives"
    unset drives

    alias sudo=gsudo

    # pure:
    # manual handling required because msys2 does not understand plain
    # 'pure.zsh' as "source with zsh", it falls back to sourcing with sh.
    # see ~/.zsh/pure/prompt_pure_setup
    source "$HOME/.zsh/pure/async.zsh"
    source "$HOME/.zsh/pure/pure.zsh"
    source "$HOME/.vsdevenv.sh"

    alias reboot='powershell.exe -command restart-computer'
    alias shutdown='powershell.exe -command stop-computer'
    ;;
esac

# load fpath completion functions
autoload -Uz bashcompinit compinit; bashcompinit; compinit

eval "$(fzf --zsh)"
# don't have ESC+c start fzf
bindkey -s '\ec' ''
eval "$(zoxide init zsh --cmd cd)"

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

# hook the custom precmd function
add-zsh-hook precmd prompt_pure_precmd

# ensure vcs_info is loaded for git status
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git*' formats "%b"
