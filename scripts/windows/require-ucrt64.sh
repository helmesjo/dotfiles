#!/usr/bin/env bash
# Sourced by any entry point that assumes a genuine MSYS2 UCRT64 shell
# (setup.sh, scripts/install.sh, scripts/configure.sh). Each of those can be
# run standalone rather than only via setup.sh, so each verifies this
# independently instead of trusting a prior caller.
#
# $MSYSTEM is checked directly. uname -s can't be used for this: MSYS2's
# uname reports 'MINGW64_NT-...' for the whole 64-bit mingw family (MINGW64,
# UCRT64, CLANG64 all share it), so it can never distinguish a genuine
# UCRT64 shell from a MINGW64 one - it would fail this check unconditionally.
# $MSYSTEM can be overridden later by .env.local, but that only runs once
# this repo's dotfiles are symlinked in, at which point setup has already
# succeeded once and every shell is intentionally normalised to UCRT64 -
# so on a fresh machine (the case this guard actually protects), $MSYSTEM
# still reflects the real subsystem the shell was launched with.

if [[ ${MSYSTEM:-} != UCRT64* ]]; then
  {
    echo "ERROR: this script must be run from a genuine MSYS2 UCRT64 shell."
    echo "  \$MSYSTEM='${MSYSTEM:-<unset>}'"
    if ! command -v pacman &>/dev/null; then
      echo "  no 'pacman' on PATH - this looks like Git for Windows (Git Bash), not MSYS2."
    else
      echo "  MSYS2 detected, but in the wrong subsystem - relaunch with '-ucrt64'."
    fi
    echo
    echo "First time on this machine? Run bootstrap.ps1 from PowerShell (see README.md)."
    echo "Already set up before? Use the 'MSYS2 UCRT64' shell shortcut, then try again."
  } >&2
  exit 1
fi
