#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR
unalias -a # disable aliases for script

export MSYS=winsymlinks:nativestrict

this_dir=$(dirname $(readlink -f $BASH_SOURCE))

# Msys: Deal with '/' being parsed as path & not cmd flag
CMD_EXE=($(dir.exe $(which cmd.exe)))
case "${MSYSTEM:-}" in
    MINGW*) CMD_EXE+=(//C);;
    *)      CMD_EXE+=(/C);;
esac

${CMD_EXE[@]} " reg.exe import "$(cygpath -w $this_dir)/settings.reg" "
