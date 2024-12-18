#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

export MSYS=winsymlinks:nativestrict

# Symlinks for shortcuts requires elevated privileges.
if ! net session > /dev/null 2>&1; then
  echo "Re-run as admin" >&2
  exit 1
fi

this_dir=$(dirname $(readlink -f $BASH_SOURCE))

# Msys: Deal with '/' being parsed as path & not cmd flag
CMD_EXE=($(dir.exe $(which cmd.exe)))
case "$(uname -s)" in
    MINGW*) CMD_EXE+=(//C);;
    *)      CMD_EXE+=(/C);;
esac

${CMD_EXE[@]} "reg.exe import "$(cygpath -u $this_dir)/settings.reg""
