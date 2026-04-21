bindkey '^[[1;3C' forward-word                   # alt+right
bindkey '^[[1;3D' backward-word                  # alt+left
bindkey '^[[3~'   delete-char                    # 'Del' key

# Shift+Enter: insert a literal newline into the ZLE buffer (no execute, no dquote prompt)
_zle_shift_enter() { LBUFFER+=$'\n' }
zle -N _zle_shift_enter
bindkey $'\e[13;2u' _zle_shift_enter
bindkey '\e^J' undefined-key  # disable built-in newline insertion on Alt+Enter (ESC+LF)
bindkey '\e^M' undefined-key  # same, covers both sequences terminals may send (ESC+CR)
