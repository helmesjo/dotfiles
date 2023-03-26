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
        case '*'
            fish_add_path -aP ~/.local/bin # mainly pip packages
    end

    # Aliases
    source ~/.shell-aliases

    # Export
    set -x FZF_DEFAULT_COMMAND rg --files --hidden
    set -x FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
    set -x FZF_COMPLETION_TRIGGER ??
end
