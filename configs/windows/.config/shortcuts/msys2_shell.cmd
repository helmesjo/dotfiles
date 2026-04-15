@echo off

rem HOME is required else MSYS creates its own /home/<user> dir which messes things up.
rem It needs to be converted to forward-slashes.
set "HOME=%USERPROFILE%"

rem winsymlinks:native  - use Windows native symlinks (mklink) instead of MSYS2 fake symlinks.
rem disable_pcon        - skip MSYS2's ConPTY setup: no cygwin-console-helper.exe is spawned and
rem                       no hooks are installed on console API calls (WriteFile, ReadConsoleA/W,
rem                       etc.). without this, every PTY write is intercepted to translate between
rem                       Windows console semantics and the PTY, adding overhead on each keystroke.
rem                       safe when the terminal is already a ConPTY host (e.g. Alacritty): native
rem                       Windows programs attach to the terminal's ConPTY directly, so MSYS2's
rem                       secondary bridge is redundant. would break native programs under terminals
rem                       that are not ConPTY hosts (e.g. mintty).
set "MSYS=winsymlinks:nativestrict disable_pcon"

IF EXIST "C:\msys64\msys2_shell.cmd" (
  C:\msys64\msys2_shell.cmd %*
  IF ERRORLEVEL 1 (
    ECHO Failed to start shell >&2
    cmd.exe
  )
) ELSE (
    ECHO File C:\msys64\msys2_shell.cmd does not exist, install Msys2: winget install Msys2
    cmd.exe
    exit 1
)
