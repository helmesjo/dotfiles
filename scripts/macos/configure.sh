#!/usr/bin/env bash
set -eu -o pipefail

this_dir=$(dirname $(readlink -f $BASH_SOURCE))

$this_dir/configure-fzf.sh
