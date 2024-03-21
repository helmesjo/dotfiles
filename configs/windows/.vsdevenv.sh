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

VS_ENVAR_CACHE="$(cygpath -m ~/.vsdevenv.cache)"
function vsdevenv_export_envars()
{
    # Read file line by line and extract variables
    set -o allexport
    source $VS_ENVAR_CACHE
    PATH="$PATH:$VCPATHS"
    set +o allexport
    # Remove clashing tools (eg. msys2 link.exe)
    bad_linkers=($(which -a link.exe | grep -v "$(cygpath -u "$VCToolsInstallDir")"))
    for f in ${bad_linkers[@]}; do test -f "$f" && printf '%s' "conflicting link.exe, " && mv -v "$f" "$f.bak"; done

    which cl.exe >/dev/null 2>&1 || echo "Failed to find cl.exe"
    return 0
}

# prefix common commands so that aliases and functions are ignored
$C command

# If on windows and not in developer prompt (or with wrong architecture), try to set it up
if [[ "$(uname -s)" =~ MINGW*|CYGWIN* ]];then
    REQUIRE_PROMPT=0
    if [ ! -n "${HOST_ARCH-}" ]; then
        HOST_ARCH=$(uname -m)
    fi
    if [ ! -n "${TARGET_ARCH-}" ]; then
        TARGET_ARCH=$(uname -m)
    fi

    TARGET_ARCH_CONV=$($C echo -e "$CL_ARCH_TABLE" | $C tr -d ' ' | $C grep "^$HOST_ARCH-$TARGET_ARCH:" | $C awk -F':' '{print $2}')

    if cl.exe >/dev/null 2>&1;then
        # Figure out if we already are in the correct dev prompt (matching architecture)
        CL_ARCH=$(cl.exe 2>&1 | $C grep "Compiler.*for" | $C awk '{print $NF}')
        if [ "$CL_ARCH" != "$TARGET_ARCH_CONV" ];then
          REQUIRE_PROMPT=1
        fi
    else
        REQUIRE_PROMPT=1
    fi

    # Find path to latest VS version
    VSDIR="C:/Program Files/Microsoft Visual Studio"
    if ! test -f "$VSDIR"; then
        VSDIR="C:/Program Files (x86)/Microsoft Visual Studio"
    fi
    VSVER_LATEST=$($C ls -1 "$VSDIR" \
                    | $C grep "[[:digit:]]" | $C sort -r | $C head -n 1)

    if [ $REQUIRE_PROMPT -eq 1 ];then
        # See if VS PATHs has been cached already
        if [ -f "$VS_ENVAR_CACHE" ]; then
            # Read file line by line and extract variables
            vsdevenv_export_envars
            return 0
        fi

        echo -e "\n-- Setting up developer prompt ($TARGET_ARCH_CONV) in '$VSDIR/$VSVER_LATEST'"
        if [ ! -d "$VSDIR" ]; then
            echo "Failed to find Visual Studio installation in '$VSDIR'."
            return 1
        fi

        VSVARSALL="$($C find "$VSDIR/$VSVER/" -type f -name "vcvarsall.bat" -print -quit)"

        if [ ! -f "$VSVARSALL" ]; then
            echo "Failed to find 'vsvarsall.bat' in '$VSDIR'."
            return 1
        fi

        VSVARSALL="$(cygpath -w $VSVARSALL)"

        # Msys: Deal with '/' being parsed as path & not cmd flag
        case "$(uname -s)" in
            MINGW*) CMD_EXE=(cmd //C);;
            *)      CMD_EXE=(cmd /C);;
        esac

        # Inside dev prompt, export all envars (using 'export -p'),
        # then extract only the relevant 'PATH' values
        VS_ENVARS_TMP="${VS_ENVAR_CACHE}.tmp"
        > $VS_ENVAR_CACHE
        > $VS_ENVARS_TMP
        ${CMD_EXE[@]} " "$VSVARSALL" $TARGET_ARCH_CONV >NUL && bash -c "export -p >$VS_ENVARS_TMP""
        # Clear cache then fill with diff (that is, only the VS stuff).
        # Deal specifically with 'PATH' to subtract the current PATH. Store result in 'VCPATHS'.
        while read -r line; do
          if [[ "${line%=*}" == "declare -x PATH" ]]; then
            # Remove leading and trailing quotes to not mess up if-check
            VCPATHS_EXPORTED=$(sed -e 's/^"//' -e 's/"$//' <<<${line#*=})
            ( IFS=:
              VCPATHS=""
              for p in $VCPATHS_EXPORTED; do
                p="$(cygpath -u "$p")"
                if [ -d "$p" ] && [[ ":$PATH:" != *":$p:"* ]]; then
                    VCPATHS="${VCPATHS:+"$VCPATHS:"}$p"
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

        rm $VS_ENVARS_TMP
        vsdevenv_export_envars
        echo "-- Cached VS envars: '$(cygpath -m $VS_ENVAR_CACHE)'"
    else
        echo -e "-- Already running dev prompt ($TARGET_ARCH_CONV) in '$VSDIR/$VSVER_LATEST'"
    fi
fi
