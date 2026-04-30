#!/bin/bash
set -eu -o pipefail

this_dir=$(dirname $(readlink -f $BASH_SOURCE))

# Msys: Deal with '/' being parsed as path & not cmd flag
CMD_EXE=($(dir.exe $(which cmd.exe)))
case "$(uname -s)" in
    MINGW*) CMD_EXE+=(//C);;
    *)      CMD_EXE+=(/C);;
esac

${CMD_EXE[@]} " "$(cygpath -m "$this_dir/browser-selector-reg.bat")" "

echo "  - browser-selector.bat is now the default browser."
