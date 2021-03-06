# Silence intro
set fish_greeting

# Envars
set -x VISUAL helix
set -x EDITOR $VISUAL

if status is-interactive
    # Path to file, or source if symlink.
    set config_path (dirname (readlink -m (status --current-filename)))
    set dotfiles_root (git -C $config_path rev-parse --show-toplevel)
    # Sourcing

    # Export
    set -x FZF_DEFAULT_COMMAND rg --files --hidden
    set -x FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
    set -x FZF_COMPLETION_TRIGGER ??

    # Aliases
    alias cat='bat'
    alias config='git -C $dotfiles_root'
    alias ls='ls --color=auto'
end
