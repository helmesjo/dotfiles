#!/usr/bin/env bash
#
# BrowserSelector - URL router
# Routes specific domains (work/corporate) to one browser,
# everything else to your current system default browser.
#

set -euo pipefail

# Domains that should open in the WORK browser (regex)
WORK_DOMAINS=(
    "azure.com"
    "dynamics.com"
    "login.microsoftonline.com"
    "microsoft.com"
    "office.com"
    "portal.azure.com"
    "powerbi.com"
    "sharepoint.com"
    "teams.com"
)

# Convert the list into a single regex: (domain1)|(domain2)|...
IFS='|'
WORK_REGEX="(${WORK_DOMAINS[*]})"
unset IFS

get_default_browser_cmd() {
    case "$OSTYPE" in
        linux*)
            echo "xdg-open"
            ;;
        darwin*)
            echo "open"
            ;;
        *)
            echo "xdg-open"
            ;;
    esac
}

get_work_browser_cmd() {
    case "$OSTYPE" in
        linux*)
            if command -v microsoft-edge-stable &>/dev/null; then
                echo "microsoft-edge-stable"
            elif command -v microsoft-edge &>/dev/null; then
                echo "microsoft-edge"
            else
                get_default_browser_cmd
            fi
            ;;
        darwin*)
            echo "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
            ;;
        *)
            echo "[browser-selector] couldn't determine work browser" >&2
            exit 1
            ;;
    esac
}

DEFAULT_CMD=$(get_default_browser_cmd)
WORK_CMD=$(get_work_browser_cmd)

url="${1:-}"

if [[ -z "$url" ]]; then
    echo "usage: $0 <url>"
    exit 1
fi

if [[ "$url" =~ $WORK_REGEX ]]; then
    echo "[browser-selector] using work browser"
    eval "$WORK_CMD \"$url\""
else
    echo "[browser-selector] using system default browser"
    eval "$DEFAULT_CMD \"$url\""
fi
