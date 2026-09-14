#!/usr/bin/env bash
set -eu -o pipefail

function on_error {
    echo "Failed: '$2' exited with $? at ${BASH_SOURCE[0]}:$1" >&2
    exit 1
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

file_dir=`dirname $(readlink -f "${BASH_SOURCE[0]:-$0}")`

# vc++ build tools (if not already available in path or installed): a
# subshell isolates .vsdevenv.sh's own variables/functions from ours; its
# exit code is non-zero iff cl.exe wasn't found/set up.
if ! ( source "$file_dir/.vsdevenv.sh" ) >/dev/null; then
  winget install --force \
                 --disable-interactivity \
                 --accept-source-agreements \
                 --accept-package-agreements \
                 --id=Microsoft.VisualStudio.2022.BuildTools \
                 --override "--quiet --wait \
                   --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
                   --add Microsoft.VisualStudio.Component.Windows11SDK.26100 \
                 "
fi
