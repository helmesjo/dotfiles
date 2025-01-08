#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

export MSYS=winsymlinks:nativestrict

# NOTE: Below are some speed-up tricks found online.
#       It avoids querying Windows for user details.

# Create local account details to avoid msys querying
# from windows each time. Run 'trace ls' for details
# of what msys executes all the time.
mkpasswd -l -c > /etc/passwd
mkgroup -l -c > /etc/group

if [ -f /etc/nsswitch.conf ]; then
  if ! test -f /etc/nsswitch.conf.bak 2>&1 >/dev/null; then
    cp /etc/nsswitch.conf /etc/nsswitch.conf.bak
  fi

  sed -E \
    -e 's/^(passwd:).*/\1 files # db/' \
    -e 's/^(group:).*/\1 files # db/' \
    -i'' \
    /etc/nsswitch.conf
fi
