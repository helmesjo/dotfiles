#
# ~/.zshrc
#

export LC_ALL=en_US.UTF-8
VISUAL=hx
EDITOR="$VISUAL"

# Plugins
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.zsh/zsh-history-substring-search/zsh-history-substring-search.zsh

# Bindings
bindkey '^[[A' history-substring-search-up    # arrow-up
bindkey '^[[B' history-substring-search-down  # arrow-down
bindkey "^[[1;3C" forward-word                # alt+right
bindkey "^[[1;3D" backward-word               # alt+left

# Aliases
source ~/.bazsh_aliases

case "$(uname -o)" in
  Darwin)
    if [[ ! "$PATH" == */opt/homebrew/opt/llvm/bin* ]]; then
      PATH="${PATH:+${PATH}:}/opt/homebrew/opt/llvm/bin"
    fi
    ;;
  GNU/Linux)
    ;;
  MSYS|MINGW32|MINGW64)
    PATH="$PATH:~/AppData/Local/Microsoft/WinGet/Links"
    PATH="$PATH:~/AppData/Local/Microsoft/WindowsApps"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/tre-command/bin")"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/gsudo/Current")"
    PATH="$PATH:/c/build2/bin"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/Git/mingw64/bin")"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/LLVM/bin")"
    PATH="$PATH:~/.cargo/bin"

    alias sudo=gsudo
    ;;
esac

eval "$(fzf --zsh)"
eval "$(zoxide init zsh --cmd cd)"

# pure (see install-pure.sh)
(( ! ${fpath[(Ie)$HOME/.zsh/pure]} )) && fpath+=$HOME/.zsh/pure
autoload -U promptinit; promptinit
prompt pure

# custom prompt (single-line)
function prompt_pure_precmd() {
  local last_command_exit=$?
  local dir="%~"

  # git information
  vcs_info

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
  PROMPT="%F{blue}${dir}%f %F{magenta}${vcs_info_msg_0_}%f ${error_code}${prompt_symbol} "

  # clear any existing right prompt
  RPROMPT=""
}

# ensure vcs_info is loaded for git status
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git*' formats "%b"

# hook the precmd function
add-zsh-hook precmd prompt_pure_precmd
