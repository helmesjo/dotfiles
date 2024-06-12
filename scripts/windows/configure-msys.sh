#!/usr/bin/env bash
set -eu -o pipefail

# Must run with correct HOME dir set and as admin
if [[ "$HOME" != $(cygpath -u "$USERPROFILE") ]] || ! net session > /dev/null 2>&1; then
  # Must run with correct home directory,
  # else it'll create it's own within msys2.
  MSYS=winsymlinks:nativestrict
  HOME=$(cygpath -u "$USERPROFILE")
  this_script="$(cygpath -u "$(readlink -f $BASH_SOURCE)")"

  echo "Re-running as admin with HOME=$HOME"
  "$(cygpath -u "$PROGRAMFILES/gsudo/Current/gsudo")" \
    bash -c "$this_script;exit \$?";exit $?
fi

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
