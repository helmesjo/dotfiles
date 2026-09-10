#
# ~/.bashrc
#

[[ -f "$HOME/.env" ]] && { set -a; source "$HOME/.env"; set +a; }

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Enable shared history
touch ~/.bash_history
chmod 600 ~/.bash_history
export HISTFILE=~/.bash_history
export HISTSIZE=1000
export HISTFILESIZE=2000
export HISTCONTROL=erasedups:ignorespace
export HISTTIMEFORMAT='%F %T '
shopt -s histappend

PS1='[\u@\h \W]> '

# platform-specific setup
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
    alias reboot='powershell.exe -command restart-computer'
    alias shutdown='powershell.exe -command stop-computer'
    ;;
esac

# see: .shell-aliases
# NOTE: MacOS already has 'open' that does the right thing.
name=open
if ! command -v $name >/dev/null || [[ $(type -t $name) == "alias" ]]; then
  alias $name="_open_file_explorer"
fi

# source aliases
source ~/.bazsh_aliases

# Load drop-in configs
for f in ~/.bashrc.d/*.bash; do [[ -r "$f" ]] && source "$f"; done
