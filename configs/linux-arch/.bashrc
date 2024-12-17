#
# ~/.bashrc
#

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
VISUAL=hx
EDITOR="$VISUAL"

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='[\u@\h \W]\$ '

# Aliases
source ~/.bazsh_aliases

case "$(uname -o)" in
  GNU/Linux)
    if [[ "$(uname -r)" == *WSL* ]]; then
      if ! test -f /mnt/c/Program\ Files/Git/mingw/bin/git-credential-manager.exe; then
        export GIT_CONFIG_COUNT=1
        export GIT_CONFIG_KEY_0=credential.helper
        export GIT_CONFIG_VALUE_0='/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe'

        # when running in wsl, override 'cmd not found' handler and
        # see if there is an .exe file available to avoid explicitly
        # spelling it out each time.
        function command_not_found_handle() {
          local cmd="$1"
          shift
          # Check if the command with .exe exists
          if [ -x "$(command -v "$cmd.exe")" ]; then
            "$cmd.exe" "$@"
          else
            # If no .exe is found, use the default command-not-found handler
            if [ -x /usr/lib/command-not-found ]; then
              /usr/lib/command-not-found "$cmd"
            else
              echo "$cmd: command not found" >&2
              return 127
            fi
          fi
        }
        export -f command_not_found_handle
      fi
    fi
    ;;
  Msys|MINGW32|MINGW64)
    PATH="$PATH:$HOME/AppData/Local/Microsoft/WinGet/Links"
    PATH="$PATH:$HOME/AppData/Local/Microsoft/WindowsApps"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/tre-command/bin")"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/gsudo/Current")"
    PATH="$PATH:/c/build2/bin"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/Git/mingw64/bin")"
    PATH="$PATH:$(cygpath -u "$PROGRAMFILES/LLVM/bin")"
    PATH="$PATH:$HOME/.cargo/bin"

    source "$HOME/.vsdevenv.sh"
    ;;
esac

eval "$(fzf --bash)"
eval "$(zoxide init bash --cmd cd)"
