@echo off

set MSYS=winsymlinks:nativestrict
C:\msys64\msys2_shell.cmd -defterm -here -no-start -ucrt64 -shell bash -c "source ~/.vsdevenv.sh && fish"
