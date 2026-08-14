eval "$(zoxide init zsh --cmd cd)"
[[ -f $HOME/.cargo/env ]] && source "$HOME/.cargo/env" || true

export PATH="$HOME/.grok/bin:$PATH" # grok
export GROK_SHELL=bash
