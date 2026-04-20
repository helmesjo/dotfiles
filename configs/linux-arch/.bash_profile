# ~/.bash_profile: bash login shell entry point.
# Explicitly chain to ~/.profile so bash reliably sources it regardless of
# whether other tools (rustup, conda, nvm, etc.) append to this file.
[[ -f "$HOME/.profile" ]] && . "$HOME/.profile"

# Bash login shells don't source ~/.bashrc automatically. Skip it if
# non-interactive (e.g. `ssh host 'cmd'`). .bashrc has the same guard
# but checking here avoids the fork to source it at all.
[[ $- != *i* ]] && return
[[ -f "$HOME/.bashrc" ]] && . "$HOME/.bashrc"
