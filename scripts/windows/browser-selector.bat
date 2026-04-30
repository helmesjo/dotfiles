@echo off
setlocal EnableDelayedExpansion

set "URL=%~1"
if "%URL%"=="" exit /b 1

set "WORK_DOMAINS=azure.com portal.azure.com login.microsoftonline.com microsoft.com office.com sharepoint.com dynamics.com powerbi.com teams.com"

set "IS_WORK=0"
for %%D in (%WORK_DOMAINS%) do (
    echo "!URL!" | findstr /i /c:"%%D" >nul && set "IS_WORK=1"
)

if !IS_WORK!==1 (
    start /b "" "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" "!URL!"
) else (
    start /b "" "%ProgramFiles%\Zen Browser\zen.exe" "!URL!"
)

endlocal
