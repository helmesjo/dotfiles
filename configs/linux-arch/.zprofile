# ~/.zprofile: zsh login shell setup.
# Zsh doesn't source ~/.profile automatically; we do it here.
[[ -f "$HOME/.profile" ]] && emulate sh -c 'source "$HOME/.profile"'
