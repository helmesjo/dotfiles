# ~/.profile: PATH setup for login shells.
# Sourced automatically by bash; zsh sources this via ~/.zprofile.

pathappend() {
  for arg in "$@"; do
    case ":$PATH:" in
      *":$arg:"*) ;;
      *) PATH="${PATH:+$PATH:}$arg" ;;
    esac
  done
  unset arg
}

mkdir -p "$HOME/.local/bin"
pathappend "$HOME/.local/bin"

case "$(uname -s)" in
  Darwin)
    brew_path=$(brew --prefix)
    pathappend "$brew_path/bin"
    pathappend "$brew_path/opt/llvm/bin"
    unset brew_path
    ;;
  Linux)
    case "$(uname -r)" in
      *WSL*|*microsoft*)
        # Rotate PATH: Windows-mounted (/mnt/X/) paths go last.
        _old_ifs=$IFS
        IFS=:
        _keep='' _move=''
        for _p in $PATH; do
          case "$_p" in
            /mnt/[A-Za-z]/*) _move="${_move:+$_move:}$_p" ;;
            *)                _keep="${_keep:+$_keep:}$_p" ;;
          esac
        done
        PATH="${_keep:+$_keep:}$_move"
        IFS=$_old_ifs
        unset _old_ifs _keep _move _p
        ;;
    esac
    ;;
  MSYS*|MINGW*|CYGWIN*)
    pathappend "$HOME/AppData/Local/Microsoft/WinGet/Links"
    pathappend "$HOME/AppData/Local/Microsoft/WindowsApps"
    pathappend "$(cygpath -u "$PROGRAMFILES/tre-command/bin")"
    pathappend "$(cygpath -u "$PROGRAMFILES/gsudo/Current")"
    pathappend "$(cygpath -u "$PROGRAMFILES/Git/mingw64/bin")"
    pathappend "$(cygpath -u "$PROGRAMFILES/LLVM/bin")"
    pathappend "/c/build2/bin"
    ;;
esac

unset -f pathappend
