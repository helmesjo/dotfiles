eval "$(zoxide init zsh --cmd cd)"
if [[ $OSTYPE =~ ^(cygwin|msys|win32) ]]; then
  # zoxide 0.10.0 emits `cygpath -w "\builtin pwd -L"` (missing $(...)), so it
  # converts that literal string instead of the actual cwd. Fixed upstream in
  # ajeetdsouza/zoxide#1260 but not yet released, override until it lands.
  __zoxide_pwd() {
    \command cygpath -w "$(\builtin pwd -L)"
  }
fi
[[ -f $HOME/.cargo/env ]] && source "$HOME/.cargo/env" || true

export PATH="$HOME/.grok/bin:$PATH" # grok
