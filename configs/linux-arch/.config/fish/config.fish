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
    # Aliases
    source ~/.shell-aliases

    # PATH
    switch (uname -o)
        case Darwin
            fish_add_path -pP /opt/pkgin/bin
            fish_add_path -pP /opt/homebrew/bin
            fish_add_path -pP /opt/homebrew/opt/llvm/bin # lldb-vscode
        case Windows Msys
            fish_add_path -aP $(cygpath -u "$PROGRAMFILES/Git/mingw64/bin")
            fish_add_path -aP ~/AppData/Local/Microsoft/WinGet/Links
            fish_add_path -aP ~/AppData/Local/Microsoft/WindowsApps
            fish_add_path -aP $(cygpath -u "$PROGRAMFILES/tre-command/bin")
            fish_add_path -aP $(cygpath -u "$PROGRAMFILES/gsudo/Current")
            fish_add_path -aP $(cygpath -u "$PROGRAMFILES/LLVM/bin")
            fish_add_path -aP "/c/build2/bin"
            fish_add_path -aP ~/.cargo/bin

            alias sudo=gsudo
        case '*'
            fish_add_path -aP ~/.local/bin # mainly pip packages
    end

    fzf --fish | source
    zoxide init fish --cmd cd | source
end
