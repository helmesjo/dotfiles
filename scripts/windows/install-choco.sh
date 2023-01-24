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
    "powershell" -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; powershell [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
fi
