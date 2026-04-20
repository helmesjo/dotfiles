#!/usr/bin/env bash
set -eu -o pipefail
unalias -a # disable aliases for script

# Zen Browser: use existing profile instead of creating a new one on first launch.
# REG_EXPAND_SZ so %USERPROFILE% is expanded at login before the value reaches the process.
reg_set() {
  local key=$1 name=$2 type=$3 value=$4
  local current
  current=$(MSYS2_ARG_CONV_EXCL="*" reg.exe query "$key" /v "$name" 2>/dev/null | grep -i "$type" | sed "s/.*$type[[:space:]]*//" | tr -d '\r') || true
  [[ "$current" == "$value" ]] && return
  MSYS2_ARG_CONV_EXCL="*" reg.exe add "$key" /v "$name" /t "$type" /d "$value" /f
}

reg_set "HKCU\Environment" XRE_PROFILE_PATH       REG_EXPAND_SZ '%USERPROFILE%\.config\zen\13pmdhsh.fho'
reg_set "HKCU\Environment" XRE_PROFILE_LOCAL_PATH REG_EXPAND_SZ '%USERPROFILE%\.cache\zen\profile'
reg_set "HKCU\Environment" MOZ_LEGACY_PROFILES    REG_SZ        '1'
