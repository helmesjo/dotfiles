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

# prefix common commands to that aliases and functions are ignored
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

    if $C cl.exe >/dev/null 2>&1;then
        # Figure out if we already are in the correct dev prompt (matching architecture)
        CL_ARCH=$($C cl.exe 2>&1 | $C grep "Compiler.*for" | $C awk '{print $NF}')
        if [ "$CL_ARCH" != "$TARGET_ARCH_CONV" ];then
          REQUIRE_PROMPT=1
        fi
    else
        REQUIRE_PROMPT=1
    fi

    # Find path to latest VS version
    VSDIR="C:/Program Files/Microsoft Visual Studio"
    VSVER_LATEST=$($C ls -1 "$VSDIR" \
                    | $C grep "[[:digit:]]" | $C sort -r | $C head -n 1)

    if [ $REQUIRE_PROMPT -eq 1 ];then
        # See if VS PATHs has been cached already
        VS_ENVAR_CACHE=~/.vsdevenv.cache
        if [ -f "$VS_ENVAR_CACHE" ]; then
            VS_PATHS=$(<$VS_ENVAR_CACHE)
            declare -x PATH="$PATH:$VS_PATHS"
            # echo "-- Loaded cached VS envars: '$VS_ENVAR_CACHE'"
            # $C cl.exe >/dev/null 2>&1
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

        # Inside dev prompt, export all envars (using 'export -p') and run with 'eval' to
        # setup current environment (basically extract everything the dev prompt sets up)
        # then extract only the 'PATH' value
        ${CMD_EXE[@]} " "$VSVARSALL" $TARGET_ARCH_CONV && bash -c "export -p >$VS_ENVAR_CACHE""
        $C sed -i '/^declare -x PATH=/!d' $VS_ENVAR_CACHE
        $C sed -i 's/^declare -x PATH=//' $VS_ENVAR_CACHE
        $C sed -i 's/\"//g' $VS_ENVAR_CACHE
        VS_PATHS=$(<$VS_ENVAR_CACHE)
        # Filter all paths not within the VS directory.
        # We just want the bare minimum.
        # The result is a string with all paths.
        VS_PATHS=$($C echo ${VS_PATHS} \
            | $C awk -v RS=: -v ORS=: '/Visual Studio/ {print} {next}' \
            | $C sed 's/:*$//')
        declare -x PATH="$PATH:$VS_PATHS"
        echo "$VS_PATHS" >$VS_ENVAR_CACHE
        echo "-- Cached VS envars: '$(cygpath -m $VS_ENVAR_CACHE)'"
    else
        echo -e "-- Already running in developer prompt ($TARGET_ARCH_CONV) in '$VSDIR/$VSVER_LATEST'"
    fi
fi
