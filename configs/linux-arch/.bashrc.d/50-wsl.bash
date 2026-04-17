[[ "$(uname -r)" != *WSL* ]] && return

# If a command isn't found, retry with .exe suffix before giving up.
command_not_found_handle() {
  local cmd=$1; shift
  if command -v "$cmd.exe" &>/dev/null; then
    "$cmd.exe" "$@"
  else
    echo "$cmd: command not found" >&2
    return 127
  fi
}
export -f command_not_found_handle

# which: fall back to .exe variant if the bare name isn't in PATH.
which() {
  local -a cmds=()
  local cmd
  for cmd in "$@"; do
    ! command -v "$cmd" &>/dev/null && command -v "$cmd.exe" &>/dev/null && cmd="$cmd.exe"
    cmds+=("$cmd")
  done
  command which "${cmds[@]}"
}
export -f which

hash -r  # ensure command lookup is up to date
