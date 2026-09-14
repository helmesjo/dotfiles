# ~/.zprofile: zsh login shell setup.
# Zsh doesn't source ~/.profile automatically; we do it here.
if [[ -f "$HOME/.profile" ]]; then
  emulate sh -c 'source "$HOME/.profile"'
fi
