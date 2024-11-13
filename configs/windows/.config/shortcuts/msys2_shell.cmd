@echo off

rem HOME is required else MSYS creates its own /home/<user> dir which messes things up.
rem It needs to be converted to forward-slashes.
set MSYS=winsymlinks:native
set "HOME=%USERPROFILE%"
set "HOME=%HOME:\=/%"

C:\msys64\msys2_shell.cmd %*
