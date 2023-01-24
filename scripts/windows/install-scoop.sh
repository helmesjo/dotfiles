#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed..."
    exit 1
}
trap on_error ERR

if ! command -v choco.exe &>/dev/null
then
    if ! net session > /dev/null 2>&1; then
        echo "Please run as admin"
        on_error
    fi
    "powershell" -Command "Set-ExecutionPolicy Bypass -Scope Process"
    "powershell" -Command "irm get.scoop.sh | iex"
fi
