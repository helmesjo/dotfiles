#!/usr/bin/env bash
set -eu -o pipefail

file_dir=$(dirname $(readlink -f $BASH_SOURCE))

$file_dir/configure-greetd.sh
$file_dir/configure-sway.sh
