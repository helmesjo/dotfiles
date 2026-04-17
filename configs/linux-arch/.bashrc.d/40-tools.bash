eval "$(fzf --bash)"
bind '"\ec": nop'  # don't have ESC+c start fzf

# Shift+Enter: insert a literal newline into the readline buffer (no execute)
_bash_shift_enter() {
  READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}"$'\n'"${READLINE_LINE:$READLINE_POINT}"
  READLINE_POINT=$((READLINE_POINT + 1))
}
bind -x '"\e[13;2u": _bash_shift_enter'

eval "$(zoxide init bash --cmd cd)"
[[ -f $HOME/.cargo/env ]] && source "$HOME/.cargo/env" || true
