bind '"\e[1;3C": forward-word'  # alt+right
bind '"\e[1;3D": backward-word' # alt+left
bind '"\e[3~":   delete-char'   # 'Del' key

# Shift+Enter: insert a literal newline into the readline buffer (no execute)
_bash_shift_enter() {
  READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}"$'\n'"${READLINE_LINE:$READLINE_POINT}"
  READLINE_POINT=$((READLINE_POINT + 1))
}
bind -x '"\e[13;2u": _bash_shift_enter'
