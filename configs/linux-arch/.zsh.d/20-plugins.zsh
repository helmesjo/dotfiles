# Plugins (antidote)
if command -v antidote &>/dev/null; then
  if [[ -f ~/.zsh_plugins.txt ]]; then
    # Re-bundle when the plugin list changes or missing bundle.
    if [[ ( ! -f ~/.zsh_plugins.sh || \
            ~/.zsh_plugins.txt -nt ~/.zsh_plugins.sh ) \
       ]]; then
      antidote bundle < ~/.zsh_plugins.txt > ~/.zsh_plugins.sh
    fi

    # load plugins
    source ~/.zsh_plugins.sh
    eval "$(fzf --zsh)"

    # customize plugin behavior
    (( ${+functions[_zsh_autosuggest_start]} )) && {
      ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    }
    (( ${+widgets[history-substring-search-up]} )) && {
      bindkey '^[[A' history-substring-search-up    # up arrow
      bindkey '^[[B' history-substring-search-down  # down arrow
    }
    (( ${+widgets[fzf-cd-widget]} )) && {
      bindkey -s '\ec' ''  # don't have ESC+c start fzf
    }

    # hook the custom precmd function
    add-zsh-hook precmd prompt_pure_precmd
    add-zsh-hook preexec prompt_pure_postprompt
  else
    echo "WARN: '~/.zsh_plugins.txt' missing" >&2
  fi
else
  echo "WARN: 'antidote' not found" >&2
fi
