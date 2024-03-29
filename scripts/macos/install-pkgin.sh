#!/usr/bin/env bash

if ! command -v pkgin &> /dev/null; then
  #
  # Copy and paste the lines below to install the Big Sur on ARM64 (M1) set.
  #
  # These packages are suitable for anyone running Big Sur (11.x) or newer on
  # Apple Silicon (M1) CPUs, and are updated from pkgsrc trunk every few days.
  #
  BOOTSTRAP_TAR="bootstrap-macos11-trunk-arm64-20211207.tar.gz"
  BOOTSTRAP_SHA="036b7345ebb217cb685e54c919c66350d55d819c"

  # Download the bootstrap kit to the current directory.
  curl -O https://pkgsrc.joyent.com/packages/Darwin/bootstrap/${BOOTSTRAP_TAR}

  # Verify the SHA1 checksum.
  echo "${BOOTSTRAP_SHA}  ${BOOTSTRAP_TAR}" | shasum -c-

  # Verify PGP signature.  This step is optional, and requires gpg.
  # curl -O https://pkgsrc.joyent.com/packages/Darwin/bootstrap/${BOOTSTRAP_TAR}.asc
  # curl -sS https://pkgsrc.joyent.com/pgp/1F32A9AD.asc | gpg2 --import
  # gpg2 --verify ${BOOTSTRAP_TAR}{.asc,}

  # Install bootstrap kit to /opt/pkg
  sudo tar -zxpf ${BOOTSTRAP_TAR} -C /

  # Reload PATH/MANPATH (pkgsrc installs /etc/paths.d/10-pkgsrc for new sessions)
  eval $(/usr/libexec/path_helper)
fi
sudo pkgin -y update