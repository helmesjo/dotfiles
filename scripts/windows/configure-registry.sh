#!/usr/bin/env bash
set -eu -o pipefail

this_dir=`dirname $(readlink -f $BASH_SOURCE)`

cmd //C " REG IMPORT "$(cygpath -w $this_dir)\\settings.reg" "
