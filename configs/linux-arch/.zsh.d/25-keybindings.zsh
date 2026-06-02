bindkey '^[[1;3C' forward-word                   # alt+right
bindkey '^[[1;3D' backward-word                  # alt+left
bindkey '^[[3~'   delete-char                    # 'Del' key

# Alt+Backspace: kill one token at a time, stopping at special characters.
# Uses %% (right-to-left C-level glob) so cost is O(token length), not O(buffer size).
# Strips trailing spaces first, then kills one run of word chars or special chars.
_zle_backward_kill_to_special() {
    setopt localoptions extendedglob
    local stripped="${LBUFFER%%[[:space:]]##}"
    if [[ -z $stripped ]]; then
        LBUFFER=''
    elif [[ $stripped = *[[:alnum:]_] ]]; then
        LBUFFER="${stripped%%[[:alnum:]_]##}"
    else
        LBUFFER="${stripped%%[^[:alnum:][:space:]_]##}"
    fi
}
zle -N _zle_backward_kill_to_special
bindkey '\e^?' _zle_backward_kill_to_special  # alt+backspace (ESC+DEL, most terminals)
bindkey '\e^H' _zle_backward_kill_to_special  # alt+backspace (ESC+BS, some terminals)

# Shift+Enter: insert a literal newline into the ZLE buffer (no execute, no dquote prompt)
_zle_shift_enter() { LBUFFER+=$'\n' }
zle -N _zle_shift_enter
bindkey $'\e[13;2u' _zle_shift_enter
bindkey '\e^J' undefined-key  # disable built-in newline insertion on Alt+Enter (ESC+LF)
bindkey '\e^M' undefined-key  # same, covers both sequences terminals may send (ESC+CR)
