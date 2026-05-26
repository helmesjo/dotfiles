#!/bin/bash
set -eu -o pipefail

INSTALL_PATH="$HOME/.local/bin/browser-selector.vbs"

echo "Installing $(basename $INSTALL_PATH)..."

mkdir -p "$HOME/.local/bin"

# Remove old PS1 variant if still present.
rm -f "$HOME/.local/bin/browser-selector.ps1"

# Read all XRE_* vars from HKCU\Environment and resolve any symlinks at
# install time. Outlook spawns the VBS with a restricted token that cannot
# traverse directory symlinks (Windows error 448). Baking the real paths
# into the VBS means no runtime resolution is needed.
xre_lines=""
while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]+(XRE_[^[:space:]]+)[[:space:]]+REG_[A-Z_]+[[:space:]]+(.+)$ ]]; then
        name="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        # Expand Windows %VAR% references (REG_EXPAND_SZ values are returned
        # unexpanded by reg query).
        if [[ "$value" == *%*%* ]]; then
            expanded=$(MSYS2_ARG_CONV_EXCL="*" cmd.exe /c "echo $value" 2>/dev/null | tr -d '\r\n') || true
            [[ -n "$expanded" ]] && value="$expanded"
        fi
        posix=$(cygpath -u "$value" 2>/dev/null) || true
        if [[ -n "$posix" ]] && real=$(realpath "$posix" 2>/dev/null); then
            resolved=$(cygpath -w "$real")
        else
            resolved="$value"
        fi
        xre_lines="${xre_lines}WshShell.Environment(\"Process\")(\"${name}\") = \"${resolved}\""$'\n'
        echo "  XRE: ${name} = ${resolved}"
    fi
done < <(MSYS2_ARG_CONV_EXCL="*" reg.exe query "HKCU\\Environment" 2>/dev/null | tr -d '\r')

if [[ -z "$xre_lines" ]]; then
    echo "  warning: no XRE_* vars found in HKCU\\Environment (run configure-zen.sh first)"
fi

cat > "$INSTALL_PATH" << EOF
Set WshShell = CreateObject("WScript.Shell")

' XRE_* vars are set to their real paths (resolved at install time, no
' symlinks). Outlook spawns this script with a restricted token that blocks
' directory symlink traversal (Windows error 448). The real paths bypass
' that restriction.
${xre_lines}
If WScript.Arguments.Count > 0 Then
    url = WScript.Arguments(0)

    Dim workDomains(8)
    workDomains(0) = "azure.com"
    workDomains(1) = "portal.azure.com"
    workDomains(2) = "login.microsoftonline.com"
    workDomains(3) = "microsoft.com"
    workDomains(4) = "office.com"
    workDomains(5) = "sharepoint.com"
    workDomains(6) = "dynamics.com"
    workDomains(7) = "powerbi.com"
    workDomains(8) = "teams.com"

    isWork = False
    For Each domain In workDomains
        If InStr(1, LCase(url), domain) > 0 Then
            isWork = True
            Exit For
        End If
    Next

    ' Use ShellExecute (exe + args as separate parameters) instead of Run (single
    ' concatenated command string). Run truncates around 2 KB on some Windows
    ' versions, which breaks long OAuth or SharePoint URLs.
    If isWork Then
        browser = WshShell.ExpandEnvironmentStrings("%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe")
        CreateObject("Shell.Application").ShellExecute browser, Chr(34) & url & Chr(34), "", "open", 1
    Else
        browser = WshShell.ExpandEnvironmentStrings("%ProgramFiles%\Zen Browser\zen.exe")
        CreateObject("Shell.Application").ShellExecute browser, "-osint -url " & Chr(34) & url & Chr(34), "", "open", 1
    End If
End If
EOF

echo "Done."
