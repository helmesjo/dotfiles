#
# ~/.zshrc
#

VISUAL=hx
EDITOR="$VISUAL"

# Aliases
source ~/.bazsh_aliases

if [[ ! "$PATH" == */opt/homebrew/opt/llvm/bin* ]]; then
  PATH="${PATH:+${PATH}:}/opt/homebrew/opt/llvm/bin"
fi

export LC_ALL=en_US.UTF-8

eval "$(fzf --zsh)"
eval "$(zoxide init zsh --cmd cd)"
