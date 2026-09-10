#
# ~/.zshrc
#

[[ -f "$HOME/.env" ]] && { set -a; source "$HOME/.env"; set +a; }

# Enable shared history
touch ~/.zsh_history
chmod 600 ~/.zsh_history
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt INC_APPEND_HISTORY_TIME
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

setopt IGNORE_EOF   # don't kill session on Ctrl+D
setopt rmstarsilent # don't prompt [y/n] on rm -rf

# zsh-specific platform setup
case "$(uname -s)" in
  Linux)
    if [[ "$(uname -r)" == *WSL* ]]; then
      # use windows git-credential-manager in WSL to avoid re-authenticating
      if test -f "$HOST___PROGRAMFILES/Git/mingw64/bin/git-credential-manager.exe" && \
         ! test -L ~/.local/bin/git-credential-manager.exe >/dev/null; then
        ln -sv "$HOST___PROGRAMFILES/Git/mingw64/bin/git-credential-manager.exe" ~/.local/bin
      fi

    fi
    ;;
  MSYS*|MINGW*|CYGWIN*)
    # complete hard drives in msys2
    drives=$(mount | sed -rn 's#^[A-Z]: on /([a-z]).*#\1#p' | tr '\n' ' ')
    zstyle ':completion:*' fake-files /: "/:$drives"
    unset drives
    ;;
esac

# Load drop-in configs
for f in ~/.zsh.d/*.zsh(N); do source "$f"; done

# source aliases
source ~/.bazsh_aliases
