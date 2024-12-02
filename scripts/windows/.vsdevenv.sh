#!/usr/bin/env bash

function vsdevenv_is_sourced()
{
  if [[ -z ${vsdevenv__caller:-} ]]; then
    local vsdevenv__caller=$([ -n "$ZSH_VERSION" ] && \
                              echo $ZSH_EVAL_CONTEXT || echo ${0##*/})
  fi
  case $vsdevenv__caller in
    dash|-dash|bash|-bash|ksh|-ksh|sh|-sh|*:file:*)
      return 0;;
  esac
  return 1 # NOT sourced.
}

if ! vsdevenv_is_sourced; then
  vsdevenv__caller="toplevel:file:cmdsubset"
  this_script="$(readlink -f "${BASH_SOURCE[0]:-$0}")"
  source "$this_script"; ec=$?
  which cl.exe
  exit $ec
fi

#  Table for converting between our representation of architecture
## to that of Microsoft/CL.exe fantasy land.
## See: https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line?view=msvc-170#vcvarsall-syntax
## OURS(HOST_ARCH-TARGET_ARCH):THEIRS
CL_ARCH_TABLE='
x86_64-x86    : x64_x86
x86_64-x86_64 : x64
x86_64-arm64  : x64_arm64
x86_64-arm32  : x64_arm
'

# prefix common commands so that aliases and functions are ignored
C=command

# NOTE: Don't use '~' since all envars are cleared before
#       starting devprompt to extract only new vars.
#       'readlink -f' is so that we get the real windows user path.
VS_ENVAR_CACHE="$(cygpath -u "$(readlink -f ~/.vsdevenv.cache)")"

function vsdevenv_retard_path()
{
  # cmd.exe is retarded and needs retarded paths
  # with double forward-slashes.
  echo -e "${1//\////}"
}

function vsdevenv_remove_clashing_bins()
{
  # Remove clashing tools (eg. msys2 link.exe)
  if [[ -n "${VCToolsInstallDir}" ]]; then
    bad_linkers=($(which -a link.exe 2>/dev/null | $C grep -v "$(cygpath -u "$VCToolsInstallDir")"))
    for f in ${bad_linkers[@]}; do
      f="$(cygpath -u "$f")"
      if $C test -f "$f" >/dev/null; then
        printf '%s' "-- Conflicting link.exe, "
        if ! mv -v --backup=t "$f" "$f.disabled"; then
          printf '%s\n' " - manually rename/remove it"
        fi
      fi
    done
  fi
}
function vsdevenv_export_envars()
{
    # Read file line by line and extract variables
    $C set -o allexport
    $C source "$VS_ENVAR_CACHE"
    if [[ -n "${VCPATHS:-}" ]]; then
      PATH="$PATH:$VCPATHS"
    fi
    $C set +o allexport

    if ! which cl.exe >/dev/null 2>&1; then
      $C echo "-- Failed to find cl.exe"
      return 1
    else
      vsdevenv_remove_clashing_bins
      return 0
    fi
}
function vsdevenv_find_vsvarsall_bat()
{
  local found="$($C find "$1" -type f -name "vcvarsall.bat" -print -quit)"
  if [[ -f "$found" ]]; then
    echo -e "$found"
    return 0
  else
    return 1
  fi
}

function vsdevenv_setup()
{
  # If on windows and not in developer prompt (or with wrong architecture), try to set it up
  if [[ "$(uname -o)" == Msys ]] || [[ "$(uname -o)" == Cygwin ]]; then
      if [ ! -n "${HOST_ARCH-}" ]; then
          HOST_ARCH=$(uname -m)
      fi
      if [ ! -n "${TARGET_ARCH-}" ]; then
          TARGET_ARCH=$(uname -m)
      fi

      TARGET_ARCH_CONV=$($C echo -e "$CL_ARCH_TABLE" | $C tr -d ' ' | $C grep "^$HOST_ARCH-$TARGET_ARCH:" | $C awk -F':' '{print $2}')

      REQUIRE_PROMPT=0
      if cl.exe >/dev/null 2>&1; then
          # Figure out if we already are in the correct dev prompt (matching architecture)
          CL_ARCH=$(cl.exe 2>&1 | $C grep "Compiler.*for" | $C awk '{print $NF}')
          if [ "$CL_ARCH" != "$TARGET_ARCH_CONV" ]; then
            REQUIRE_PROMPT=1
          fi
      else
          REQUIRE_PROMPT=1
      fi

      if [ $REQUIRE_PROMPT -eq 1 ]; then
          # See if VS PATHs has been cached already
          if [ -f "$VS_ENVAR_CACHE" ]; then
              # Read file line by line and extract variables
              if vsdevenv_export_envars >/dev/null; then
                return 0
              else
                echo "-- Bad cache, redo..."
                rm -v "$VS_ENVAR_CACHE"
              fi
          fi

          VS_DEFAULT_SEARCH_DIRS=(
          "$(cygpath -m "$PROGRAMFILES/Microsoft Visual Studio")"
          "$(cygpath -m "$(printenv "ProgramFiles(x86)")/Microsoft Visual Studio")"
          )

          VS_VERSIONS=()
          for ((i = 0; i < ${#VS_DEFAULT_SEARCH_DIRS[@]}; i++))
          do
            echo "-- Search: ${VS_DEFAULT_SEARCH_DIRS[$i]}"
            vsdir=$(cygpath -m "${VS_DEFAULT_SEARCH_DIRS[$i]}")

            if [[ -d "$vsdir" ]]; then
              vsdirversions=($($C ls "$vsdir"))
              # loop over all existing versions
              for vsdirver in ${vsdirversions[@]}; do
                if [[ ! "$vsdirver" =~ ^[0-9]+$ ]]; then
                  continue
                fi

                # see if this is a newer version
                VSDIR="$vsdir/$vsdirver"
                if vsdevenv_find_vsvarsall_bat "$VSDIR" >/dev/null; then
                  echo "--- Found: $(vsdevenv_find_vsvarsall_bat "$VSDIR")"
                  VS_VERSIONS+=("$VSDIR")
                fi
              done
            fi
          done

          if [[ -z ${VS_VERSIONS:-} ]]; then
            echo "-- Found no installed versions in:"
            printf '%s\n' "${VS_DEFAULT_SEARCH_DIRS[@]}"
            return 1
          fi

          VSVER_LATEST=
          VSPATH_LATEST=
          for vsdir in "${VS_VERSIONS[@]}"; do
            VSVER=$(basename "$vsdir")
            if [[ -n ${VSVER:-} ]] && [[ -z ${VSVER_LATEST} ]] || [[ $VSVER_LATEST -lt $VSVER ]]; then
              VSVER_LATEST=$VSVER
              VSPATH_LATEST="$vsdir"
            fi
          done

          VS_VARSALL="$(vsdevenv_find_vsvarsall_bat "$VSPATH_LATEST")"

          if [[ ! -f "$VS_VARSALL" ]]; then
            echo "-- Failed to find 'vsvarsall.bat' in '$VSPATH_LATEST'."
            return 1
          fi

          echo "-- Latest: $VS_VARSALL"
          echo "-- Setting up developer prompt ($TARGET_ARCH_CONV) for '$VSPATH_LATEST'"

          # Msys: Deal with '/' being parsed as path & not cmd flag
          CMD_EXE=($(dir.exe $(which cmd.exe)))
          case "$(uname -s)" in
              MINGW*) CMD_EXE+=(start //wait cmd //C);;
              *)      CMD_EXE+=(start /wait cmd /C);;
          esac

          # Inside dev prompt, export all envars (using 'export -p'),
          # then extract only the unique envars & 'PATH' values.
          VS_ENVARS_CACHE_BAK="${VS_ENVAR_CACHE}.bak"
          test -f "$VS_ENVAR_CACHE" \
            && rm -f "$VS_ENVARS_CACHE_BAK" \
            && cp "$VS_ENVAR_CACHE" "$VS_ENVARS_CACHE_BAK"

          # Run varsall.bat in a subshell & extract new envars specified by devprompt.
          # NOTE: Below is such a pain in the ass to get right, so avoid modifying.
          BASH_PATH="$(vsdevenv_retard_path "$(cygpath -m "$(which bash)")")"
          VS_VARSALL="$(vsdevenv_retard_path "$(cygpath -m "$VS_VARSALL")")"
          VS_ENVARS_TMP="$(cygpath -m "$(mktemp)")"
          ${CMD_EXE[@]} " "$VS_VARSALL" $TARGET_ARCH_CONV >NUL 2>&1 && "$BASH_PATH" -c 'export -p' " >$VS_ENVARS_TMP

          # Clear cache then fill with diff (that is, only the VS stuff).
          # Deal specifically with 'PATH' to subtract the current PATH. Store result in 'VCPATHS'.
          >"$VS_ENVAR_CACHE"
          while read -r line; do
            # Clean up path separators (sometimes double or even quad backslashes in paths)
            line="${line//\\\\\\\\//}"
            line="${line//\\\\//}"

            VAR="${line%=*}"
            VAR="${VAR#'declare -x '*}"
            VAL="${line#*=}"
            VAL="${VAL#\"}" # Removes leading "
            VAL="${VAL%\"}" # Removes trailing "

            if    [[ "$VAR"   == "$line" ]] \
               || [[ "$VALUE" == "$line" ]] \
               || [[ "$VAR"   == "_" ]]; then
              continue
            fi

            if [[ $VAR == 'PATH' ]]; then
              # Split VAL into an array using ':' as the delimiter
              VCPATH_EXPORTED=("${(s/:/)VAL}")

              VCPATHS=""
              # Loop through each path in devprompt exported PATH and add it to VCPATHS if it's not in PATH
              for p in "${VCPATH_EXPORTED[@]}"; do
                  if [[ ":$PATH:" != *":$p:"* ]]; then
                      VCPATHS="${VCPATHS:+$VCPATHS:}$p"
                  fi
              done
              echo "export VCPATHS=\"$VCPATHS\"" >>"$VS_ENVAR_CACHE"
              # echo "-- Added envar: $VCPATHS=\"$VCPATHS\""
            else
              # Only add if it doesn't already exist and has a value assigned.
              if [[ -z "$(eval echo \$$VAR 2>/dev/null)" ]]; then
                echo "export $VAR=\"$VAL\"" >> $VS_ENVAR_CACHE
                # echo "-- Added envar: $VAR=\"$VAL\""
              else
                true
                # echo "-- Skipped envar: $VAR=$VAL"
                # echo "---- Already have: $VAR=$(eval echo \$$VAR)"
              fi
            fi
          done <$VS_ENVARS_TMP

          rm -f "${VS_ENVAR_CACHE}.failed"
          if vsdevenv_export_envars; then
            rm -f "$VS_ENVARS_TMP"
            rm -f "$VS_ENVARS_CACHE_BAK"

            echo "-- $(cl 2>&1 >/dev/null | head -n 1)"
            echo "-- Cached VS envars: $(cygpath -m $VS_ENVAR_CACHE)"
            rm -f "$VS_ENVARS_CACHE_BAK"
            return 0
          else
            cp "$VS_ENVAR_CACHE" "${VS_ENVAR_CACHE}.failed"
            echo "-- Failed to export VS environment variables, see ${VS_ENVAR_CACHE}.failed"
            return 1
          fi
      else
          return 0
      fi
  fi
}

# if zsh, emulate 'bash' for this file (-L)
[[ -n "$ZSH_VERSION" ]] && ZSH_MODE=$(emulate) && emulate -L ksh
vsdevenv_setup; ec=$?
[[ -n "$ZSH_VERSION" ]] && emulate -L $ZSH_MODE
return $ec
