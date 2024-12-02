@echo off

rem HOME is required else MSYS creates its own /home/<user> dir which messes things up.
rem It needs to be converted to forward-slashes.
set MSYS=winsymlinks:native
set "HOME=%USERPROFILE%"

IF EXIST "C:\msys64\msys2_shell.cmd" (
  cmd /C "C:\msys64\msys2_shell.cmd %*"
  IF ERRORLEVEL 1 (
    ECHO Failed to start shell >&2
    cmd.exe
  )
) ELSE (
    ECHO File C:\msys64\msys2_shell.cmd does not exist, install Msys2: winget install Msys2
    cmd.exe
    exit 1
)
