#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed..."
    sleep 5
    exit 1
}
trap on_error ERR

if ! command -v choco.exe &>/dev/null
then
    cmd.exe /C "powershell Set-ExecutionPolicy Bypass -Scope Process"
    cmd.exe /C "powershell Set-ExecutionPolicy Bypass -Scope Process -Force; powershell [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
fi
