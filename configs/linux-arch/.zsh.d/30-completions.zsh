# load fpath completion functions
fpath=(~/.grok/completions/zsh $fpath) # grok
autoload -Uz bashcompinit compinit; bashcompinit; compinit

# complete hard drives in msys2
if [[ $OSTYPE == msys* || $OSTYPE == cygwin* ]]; then
  drives=$(mount | sed -rn 's#^[A-Z]: on /([a-z]).*#\1#p' | tr '\n' ' ')
  zstyle ':completion:*' fake-files /: "/:$drives"
  unset drives
fi
