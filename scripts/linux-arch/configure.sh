#!/usr/bin/env bash
set -eu -o pipefail

this_file_path=$(dirname $(readlink -f $BASH_SOURCE))

$this_file_path/configure-greetd.sh
$this_file_path/configure-nvim.sh
$this_file_path/configure-sway.sh
