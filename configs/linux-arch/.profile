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

# Batch-convert Windows/virtual paths to POSIX via a single cygpath call.
# Usage: cygpath_u path1 path2 ...  (one POSIX path per output line)
# Caller uses a heredoc to keep the consuming loop in the current shell:
#   while IFS= read -r _p; do something "$_p"; done << EOF
#   $(cygpath_u "$WINVAR/foo" "$WINVAR/bar")
#   EOF
cygpath_u() { printf '%s\n' "$@" | cygpath -u -f -; }

# Resolve MSYS2/Cygwin virtual mount paths in $PATH to their real POSIX
# equivalents (e.g. /ucrt64/bin -> /c/msys64/ucrt64/bin) so that child
# Windows processes can resolve them. Safe no-op if cygpath is absent.
path_resolve() {
  command -v cygpath > /dev/null 2>&1 || return 0
  PATH="$(printf '%s\n' "$PATH" | tr ':' '\n' | grep -v '^$' \
        | cygpath -m -f - | cygpath -u -f - | paste -sd:)"
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
    while IFS= read -r _p; do pathappend "$_p"; done << EOF
$(cygpath_u \
    "$PROGRAMFILES/tre-command/bin" \
    "$PROGRAMFILES/gsudo/Current" \
    "$PROGRAMFILES/Git/mingw64/bin" \
    "$PROGRAMFILES/LLVM/bin")
EOF
    unset _p
    pathappend "/c/build2/bin"

    case "$(uname -s)" in
      MSYS*|MINGW*)
        # Use UCRT64 runtime (Windows installer defaults to MINGW64).
        export MSYSTEM=UCRT64
        export MINGW_PREFIX=/ucrt64
        export MSYSTEM_PREFIX=/ucrt64
        export MSYSTEM_CARCH=x86_64
        export MSYSTEM_CHOST=x86_64-w64-mingw32
        ;;
    esac

    # Load base env vars (EDITOR, GOPATH, LANG, etc.).
    [ -f "$HOME/.env" ] && { set -a; . "$HOME/.env"; set +a; }

    path_resolve

    # Wire non-interactive POSIX shells spawned by headless tools to re-source
    # this file so they inherit the same environment without per-tool config.
    export ENV="$HOME/.profile"
    export BASH_ENV="$HOME/.profile"
    ;;
esac

PROFILE_WAS_SOURCED=yes
unset -f pathappend
# cygpath_u and path_resolve are kept in scope for other sourced files.
