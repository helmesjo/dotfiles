eval "$(fzf --bash)"
bind '"\ec": nop'  # don't have ESC+c start fzf

eval "$(zoxide init bash --cmd cd)"
[[ -f $HOME/.cargo/env ]] && source "$HOME/.cargo/env" || true
