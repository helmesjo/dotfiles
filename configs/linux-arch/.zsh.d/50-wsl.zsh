[[ "$(uname -r)" != *WSL* ]] && return

# If a command isn't found, retry with .exe suffix before giving up.
command_not_found_handler() {
  local cmd=$1; shift
  if (( ${+commands[$cmd.exe]} )); then
    "$cmd.exe" "$@"
  else
    print -u2 "$cmd: command not found"
    return 127
  fi
}

# which: fall back to .exe variant if the bare name isn't in PATH.
which() {
  local -a cmds=()
  local cmd
  for cmd in "$@"; do
    (( ! ${+commands[$cmd]} )) && (( ${+commands[$cmd.exe]} )) && cmd="$cmd.exe"
    cmds+=("$cmd")
  done
  command which "${cmds[@]}"
}

hash -r  # ensure $commands is fully populated
