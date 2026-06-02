bind '"\e[1;3C": forward-word'  # alt+right
bind '"\e[1;3D": backward-word' # alt+left
bind '"\e[3~":   delete-char'   # 'Del' key

# Shift+Enter: insert a literal newline into the readline buffer (no execute)
_bash_shift_enter() {
  READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}"$'\n'"${READLINE_LINE:$READLINE_POINT}"
  READLINE_POINT=$((READLINE_POINT + 1))
}
bind -x '"\e[13;2u": _bash_shift_enter'

# Alt+Backspace: kill one token at a time, stopping at special characters.
# Readline has no word-char setting, so this is implemented as a shell function.
_bash_backward_kill_to_special() {
  local i=$((READLINE_POINT - 1))
  [[ $i -lt 0 ]] && return
  # Skip trailing spaces (mimic standard backward-kill-word space-skipping)
  while [[ $i -ge 0 && "${READLINE_LINE:$i:1}" == ' ' ]]; do ((i--)); done
  [[ $i -lt 0 ]] && { READLINE_POINT=0; READLINE_LINE="${READLINE_LINE:$READLINE_POINT}"; return; }
  local char="${READLINE_LINE:$i:1}"
  if [[ "$char" =~ [[:alnum:]_] ]]; then
    while [[ $i -ge 0 && "${READLINE_LINE:$i:1}" =~ [[:alnum:]_] ]]; do ((i--)); done
  else
    while [[ $i -ge 0 && ! "${READLINE_LINE:$i:1}" =~ [[:alnum:]_[:space:]] ]]; do ((i--)); done
  fi
  local new_pt=$((i + 1))
  READLINE_LINE="${READLINE_LINE:0:$new_pt}${READLINE_LINE:$READLINE_POINT}"
  READLINE_POINT=$new_pt
}
bind -x '"\e\177": _bash_backward_kill_to_special'  # alt+backspace (ESC+DEL, most terminals)
bind -x '"\e\010": _bash_backward_kill_to_special'  # alt+backspace (ESC+BS, some terminals)
