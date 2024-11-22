#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

file_dir=$(dirname $(readlink -f $BASH_SOURCE))

$file_dir/configure-greetd.sh
$file_dir/configure-sway.sh
$file_dir/configure-helix.sh
