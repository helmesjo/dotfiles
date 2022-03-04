#!/bin/bash
set -eu -o pipefail

# Install nvim plugs
if command -v nvim &> /dev/null; then
  nvim +PlugInstall +qa
fi