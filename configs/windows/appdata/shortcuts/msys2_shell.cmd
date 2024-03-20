@echo off

set MSYS=winsymlinks:nativestrict
set MSYS2_PATH_TYPE=inherit
set MSYSTEM=UCRT64
rem HOME is required else MSYS creates its own /home/<user> dir which messes things up.
rem It needs to be converted to forward-slashes.
set "HOME=%USERPROFILE%"
set "HOME=%HOME:\=/%"
C:\msys64\msys2_shell.cmd -ucrt64 -defterm -here -no-start -use-full-path -shell bash -c "source ~/.vsdevenv.sh && fish"
