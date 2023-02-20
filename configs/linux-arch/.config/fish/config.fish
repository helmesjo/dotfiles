# Silence intro
set fish_greeting

# Disable right side prompt
function fish_right_prompt
#intentionally left blank
end

# Envars
set -x VISUAL hx
set -x EDITOR $VISUAL

if status is-interactive
    # Path to file, or source if symlink.
    set config_path (dirname (readlink -f (status --current-filename)))
    set dotfiles_root (git -C $config_path rev-parse --show-toplevel)
    
    # PATH
    switch (uname)
        case Darwin
            fish_add_path -pP /opt/pkgin/bin
            fish_add_path -pP /opt/homebrew/bin
            fish_add_path -aP /opt/homebrew/opt/llvm/bin # lldb-vscode
    end

    # Aliases
    # Make sudo work with other aliases
    alias sudo='sudo '
    alias cat='bat'
    alias config='git -C $dotfiles_root'
    alias ls='exa -l --color=auto'
    # helix doesn't have a 'hx' bin on arch
    if command -v helix &> /dev/null
        alias hx='helix'
    end

    # Export
    set -x FZF_DEFAULT_COMMAND rg --files --hidden
    set -x FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
    set -x FZF_COMPLETION_TRIGGER ??
end
