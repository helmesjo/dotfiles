#!/usr/bin/env bash
set -eu -o pipefail

# NOTE: Below are some speed-up tricks found online.
#       It avoids querying Windows for user details.

# create local account details to avoid msys querying
# from windows each time. Run 'trace ls' for details
# of what msys executes all the time.
mkpasswd -l -c > /etc/passwd
mkgroup -l -c > /etc/group

if [ -f /etc/nsswitch.conf ]; then
  rm -f /etc/nsswitch.conf.bak
  cp /etc/nsswitch.conf /etc/nsswitch.conf.bak

  sed -E \
    -e 's/^(passwd:).*/\1 files # db/' \
    -e 's/^(group:).*/\1 files # db/' \
    -i'' \
    /etc/nsswitch.conf
fi
