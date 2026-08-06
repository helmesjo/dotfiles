# load fpath completion functions
fpath=(~/.grok/completions/zsh $fpath) # grok
autoload -Uz bashcompinit compinit; bashcompinit; compinit
