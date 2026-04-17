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

# ensure vcs_info is loaded for git status
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git*' formats "%b"
