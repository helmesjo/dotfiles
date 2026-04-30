#!/bin/bash
set -eu -o pipefail

this_dir=$(dirname $(readlink -f $BASH_SOURCE))
BROWSER_SELECTOR_SH="$this_dir/browser-selector.bat"
INSTALL_PATH="$HOME/.local/bin/browser-selector.bat"

if test -f "$INSTALL_PATH"; then
  exit 0
fi

echo "Installing $(basename $BROWSER_SELECTOR_SH)..."

mkdir -p "$HOME/.local/bin"
ln -sfv "$BROWSER_SELECTOR_SH" "$INSTALL_PATH"
cat > "$INSTALL_PATH.vbs" << 'EOF'
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
If WScript.Arguments.Count > 0 Then
    url = WScript.Arguments(0)
    scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
    bat = scriptDir & "\browser-selector.bat"
    WshShell.Run """" & bat & """ """ & url & """", 0, False
End If
EOF
