#!/usr/bin/env bash
set -eu -o pipefail

this_file_path=$(dirname $(realpath $BASH_SOURCE))

# echo $this_file_path

exit

$this_file_path/configure-greetd.sh
$this_file_path/configure-nvim.sh
$this_file_path/configure-sway.sh
