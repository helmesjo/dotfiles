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

# Run via a temp .bat script rather than embedding the path (with its own
# quotes, for spaces) directly into cmd.exe's /C argument: a bash argv
# element containing literal '"' characters gets backslash-escaped by
# MSYS for native-process interop, which cmd.exe's own /C parser doesn't
# understand, so it never runs anything.
reg_cmd_script="$(mktemp --suffix=.bat)"
cat >"$reg_cmd_script" <<EOF
@echo off
reg.exe import "$(cygpath -w "$this_dir")\\settings.reg"
EOF
MSYS2_ARG_CONV_EXCL="/C" cmd.exe /C "$(cygpath -m "$reg_cmd_script")"
rm -f "$reg_cmd_script"
