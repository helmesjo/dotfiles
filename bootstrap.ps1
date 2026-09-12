#Requires -Version 5.1
<#
.SYNOPSIS
  Gets a brand-new Windows machine to a genuine MSYS2 UCRT64 shell, then
  runs ./setup.sh.
.DESCRIPTION
  Run this from PowerShell, from within an already-checked-out copy of this
  repo (e.g. `git clone` using Git for Windows, or any other way you got a
  real git checkout onto disk - a plain zip download won't work, since
  setup.sh relies on `git ls-files` to decide what to symlink).

    powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1

  Installs MSYS2 if it isn't already present, then launches a genuine
  UCRT64 shell and runs ./setup.sh from this script's own directory. Safe
  to re-run. After the first run, use the "MSYS2 UCRT64" shell shortcut and
  run ./setup.sh directly - there's no need to come back to this script
  unless the machine is being set up from scratch again.
#>

$ErrorActionPreference = 'Stop'

$RepoRoot  = $PSScriptRoot
$Msys2Root = 'C:\msys64'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Test-Command($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

if (-not (Test-Path (Join-Path $RepoRoot '.git'))) {
  Write-Error "$RepoRoot doesn't look like a git checkout (no .git). Clone this repo with git instead of downloading a zip, then run bootstrap.ps1 from inside it."
}

# 1. winget ------------------------------------------------------------------
Write-Step 'Checking for winget...'
if (-not (Test-Command 'winget')) {
  # Safe, local, no-network fallback: on many stock Win10/11 images App
  # Installer is provisioned but not yet registered for this user profile.
  try {
    Add-AppxPackage -RegisterByFamilyName `
      -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop
  } catch {}
}
if (-not (Test-Command 'winget')) {
  Write-Error @'
'winget' was not found and could not be auto-registered.
Install "App Installer" from the Microsoft Store, then re-run this script:
  https://aka.ms/getwinget
'@
}

# 2. MSYS2 ---------------------------------------------------------------
Write-Step 'Checking for MSYS2...'
if (-not (Test-Path "$Msys2Root\msys2_shell.cmd")) {
  Write-Step 'Installing MSYS2...'
  winget install --id MSYS2.MSYS2 -e `
    --accept-source-agreements --accept-package-agreements `
    --disable-interactivity --ignore-warnings
} else {
  Write-Step 'MSYS2 already installed.'
}
if (-not (Test-Path "$Msys2Root\msys2_shell.cmd")) {
  Write-Error "MSYS2 install did not produce $Msys2Root\msys2_shell.cmd - aborting."
}

# 3. Hand off to a genuine MSYS2 UCRT64 shell -------------------------------
Write-Step 'Launching MSYS2 UCRT64 shell to run setup.sh...'
$posix = '/' + $RepoRoot.Substring(0, 1).ToLower() + $RepoRoot.Substring(2).Replace('\', '/')
$cmd = "cd '$posix' && exec ./setup.sh"

# NB: 'bash', not 'zsh' - zsh is only installed BY setup.sh (install.sh's
# pacmanpkgs), so it doesn't exist yet on a virgin MSYS2 install.
$argList = @('-ucrt64', '-defterm', '-here', '-no-start', '-use-full-path', '-shell', 'bash', '-lc', $cmd)

# Start-Process (no -UseNewEnvironment) inherits this process's full
# environment block automatically, so PROGRAMFILES/APPDATA/USERPROFILE/
# PATH etc. reach the child shell with no extra plumbing.
$p = Start-Process -FilePath "$Msys2Root\msys2_shell.cmd" -ArgumentList $argList -NoNewWindow -PassThru -Wait
if ($p.ExitCode -ne 0) { Write-Error "setup.sh exited with code $($p.ExitCode)." }

Write-Step "Done. From now on, use the 'MSYS2 UCRT64' shell shortcut and run ./setup.sh directly."
