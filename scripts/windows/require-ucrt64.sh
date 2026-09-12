#!/usr/bin/env bash
# Sourced by any entry point that assumes a genuine MSYS2 UCRT64 shell
# (setup.sh, scripts/windows/install.sh, scripts/configure.sh). Each of
# those can be run standalone rather than only via setup.sh, so each
# verifies this independently instead of trusting a prior caller.
#
# uname -s is used instead of $MSYSTEM because it reports the compiled-in
# subsystem identity of that runtime's own uname.exe, independent of
# .env.local's later override of $MSYSTEM - it's the actual source
# $MSYSTEM is derived from at shell startup, so it can't be faked by a
# prior configure run.

kernel=$(uname -s 2>/dev/null || echo unknown)
if [[ $kernel != UCRT64* ]]; then
  {
    echo "ERROR: this script must be run from a genuine MSYS2 UCRT64 shell."
    echo "  detected kernel: '$kernel' (\$MSYSTEM='${MSYSTEM:-<unset>}')"
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
