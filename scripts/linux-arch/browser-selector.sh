#!/usr/bin/env bash
set -euo pipefail

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

PERSONAL_BROWSER="zen-browser"

if command -v microsoft-edge-stable &>/dev/null; then
    WORK_BROWSER="microsoft-edge-stable"
elif command -v microsoft-edge &>/dev/null; then
    WORK_BROWSER="microsoft-edge"
else
    WORK_BROWSER="$PERSONAL_BROWSER"
fi

url="${1:-}"
if [[ -z "$url" ]]; then
    echo "usage: $0 <url>" >&2
    exit 1
fi

is_work=0
for domain in "${WORK_DOMAINS[@]}"; do
    if [[ "$url" == *"$domain"* ]]; then
        is_work=1
        break
    fi
done

if [[ $is_work -eq 1 ]]; then
    exec "$WORK_BROWSER" "$url"
else
    exec "$PERSONAL_BROWSER" "$url"
fi
