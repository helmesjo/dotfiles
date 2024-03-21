#! /bin/echo This file should be sourced

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
$C command

# NOTE: Don't use '~' since all envars are cleared before
#       starting devprompt to extract only new vars.
#       'readlink -f' is so that we get the real windows user path.
VS_ENVAR_CACHE="$(cygpath -m "$(readlink -f ~/.vsdevenv.cache)")"

function vsdevenv_remove_clashing_bins()
{
  # Remove clashing tools (eg. msys2 link.exe)
  if [[ -n "${VCToolsInstallDir}" ]]; then
    bad_linkers=($(which -a link.exe 2>/dev/null | $C grep -v "$(cygpath -u "$VCToolsInstallDir")"))
    for f in ${bad_linkers[@]}; do
      f="$(cygpath -m "$f")"
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
    PATH="$PATH:$VCPATHS"
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
  echo "$($C find "$1" -type f -name "vcvarsall.bat" -print -quit)"
}

# If on windows and not in developer prompt (or with wrong architecture), try to set it up
if [[ "$(uname -s)" =~ MINGW*|CYGWIN* ]]; then
    REQUIRE_PROMPT=0
    if [ ! -n "${HOST_ARCH-}" ]; then
        HOST_ARCH=$(uname -m)
    fi
    if [ ! -n "${TARGET_ARCH-}" ]; then
        TARGET_ARCH=$(uname -m)
    fi

    TARGET_ARCH_CONV=$($C echo -e "$CL_ARCH_TABLE" | $C tr -d ' ' | $C grep "^$HOST_ARCH-$TARGET_ARCH:" | $C awk -F':' '{print $2}')

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
            if vsdevenv_export_envars; then
              return 0
            else
              rm -v "$VS_ENVAR_CACHE"
            fi
        fi

        VS_DEFAULT_SEARCH_DIRS=(
        "$(cygpath -u "$PROGRAMFILES/Microsoft Visual Studio")"
        "$(cygpath -u "$(printenv "ProgramFiles(x86)")/Microsoft Visual Studio")"
        )

        VSVER_LATEST=0
        for ((i = 0; i < ${#VS_DEFAULT_SEARCH_DIRS[@]}; i++))
        do
          vsdir=$(cygpath -m "${VS_DEFAULT_SEARCH_DIRS[$i]}")
          # loop until newest is found
          if [[ -z "${VSVARSALL}" ]]; then
            if [ -d "$vsdir" ]; then
              vsdir_latest_ver=$($C ls -1 "$vsdir" \
                               | $C grep -w "[[:digit:]]*" | $C sort -r | $C head -n 1)
              # see if this is a newer version
              if [[ -n "$vsdir_latest_ver" ]] && [[ -z ${VSVER_LATEST} ]] || [[ $VSVER_LATEST -lt $vsdir_latest_ver ]]; then
                vsvarsall="$(vsdevenv_find_vsvarsall_bat "$vsdir/$vsdir_latest_ver/")"
                if [[ -n "${vsvarsall}" ]]; then
                  VSDIR=$(cygpath -m "$vsdir")
                  VSVER_LATEST=$vsdir_latest_ver
                  VSVARSALL="$vsvarsall"
                fi
              fi
            fi
          fi
        done

        if [ ! -f "$VSVARSALL" ]; then
            echo "-- Failed to find 'vsvarsall.bat' in '$VSDIR'."
            return 1
        fi

        echo -e "\n-- Setting up developer prompt ($TARGET_ARCH_CONV) in '$VSDIR/$VSVER_LATEST'"
        echo "-- Found: $VSVARSALL"

        # Msys: Deal with '/' being parsed as path & not cmd flag
        CMD_EXE=("$(cygpath -m "$(which cmd.exe)")")
        case "$(uname -s)" in
            MINGW*) CMD_EXE+=(//S //C);;
            *)      CMD_EXE+=(/S /C);;
        esac

        # Inside dev prompt, export all envars (using 'export -p'),
        # then extract only the unique envars & 'PATH' values
        VS_ENVARS_CACHE_BAK="${VS_ENVAR_CACHE}.bak"
        VS_ENVARS_TMP="${VS_ENVAR_CACHE}.tmp.extracted"
        rm -f "$VS_ENVARS_CACHE_BAK"
        test -f "$VS_ENVAR_CACHE" && cp "$VS_ENVAR_CACHE" "$VS_ENVARS_CACHE_BAK"
        >"$VS_ENVARS_TMP"
        # TODO: Use 'env -i bash -c' to create an empty envar and really only extract those set
        #       by vs dev prompt (it becomes a quoting mess so giving up for now)
        ${CMD_EXE[@]} " "$VSVARSALL" $TARGET_ARCH_CONV >NUL && bash -c "export -p >$VS_ENVARS_TMP""
        # Clear cache then fill with diff (that is, only the VS stuff).
        # Deal specifically with 'PATH' to subtract the current PATH. Store result in 'VCPATHS'.
        >"$VS_ENVAR_CACHE"
        while read -r line; do
          if [[ "${line%=*}" == "declare -x PATH" ]]; then
            # Remove leading and trailing quotes to not mess up if-check
            VCPATHS_EXPORTED=$(sed -e 's/^"//' -e 's/"$//' <<<${line#*=})
            ( IFS=:
              VCPATHS=""
              for p in $VCPATHS_EXPORTED; do
                # add if non-empty, is a dir, has not already been added and not already in PATH, add it
                if [[ -n "${p}" ]]; then
                  p="$(cygpath -u "$p")"
                  if [ -d "$p" ] && [[ ":$VCPATHS:" != *":$p:"* ]] && [[ ":$PATH:" != *":$p:"* ]]; then
                    # filter out redundant paths
                    if [[ "$p" != "." ]] && [[ "$p" != ".." ]] && [[ "$p" != "./" ]]; then
                      VCPATHS="${VCPATHS:+"$VCPATHS:"}$p"
                    fi
                  fi
                fi
              done
              echo "VCPATHS=\"$VCPATHS\"" >>"$VS_ENVAR_CACHE"
            )
          else
            # Get var name
            VAR="${line%%=*}"
            VAR="${VAR#"declare -x "*}"

            # Only append if it doesn't already exist and has a value assigned.
            if [[ "$VAR" != "_" ]] && [ -z "${VAR:+${!VAR}}" ]; then
              VALUE="${line#*=}"
              if [[ "$VALUE" != "$line" ]]; then
                echo "$VAR=${line#*=}" >> $VS_ENVAR_CACHE
              fi
            fi
          fi
        done < "$VS_ENVARS_TMP"

        if vsdevenv_export_envars; then
          rm -f "${VS_ENVAR_CACHE}.failed"
          rm -f "$VS_ENVARS_TMP"
          rm -f "$VS_ENVARS_CACHE_BAK"
          echo "-- Cached VS envars: '$(cygpath -m $VS_ENVAR_CACHE)'"
        else
          rm -f "$VS_ENVARS_CACHE_BAK"
          rm -f "${VS_ENVAR_CACHE}.failed"
          mv "$VS_ENVAR_CACHE" "${VS_ENVAR_CACHE}.failed"
          echo "See ${VS_ENVAR_CACHE}.failed"
        fi
    else
        echo -e "-- Already running dev prompt ($TARGET_ARCH_CONV)"
        which cl.exe
        vsdevenv_remove_clashing_bins
    fi
fi
