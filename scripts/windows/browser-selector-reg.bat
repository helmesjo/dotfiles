@echo off
:: Remove any existing association
reg delete "HKCU\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice" /f 2>nul
reg delete "HKCU\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice" /f 2>nul

reg add "HKCU\Software\Classes\BrowserSelector" /ve /t REG_SZ /d "BrowserSelector URL Handler" /f >nul
reg add "HKCU\Software\Classes\BrowserSelector" /v "URL Protocol" /t REG_SZ /d "" /f >nul

reg add "HKCU\Software\Classes\BrowserSelector\Capabilities" /v "ApplicationName" /t REG_SZ /d "BrowserSelector" /f >nul
reg add "HKCU\Software\Classes\BrowserSelector\Capabilities" /v "ApplicationDescription" /t REG_SZ /d "Work/personal browser router" /f >nul

reg add "HKCU\Software\Classes\BrowserSelector\Capabilities\UrlAssociations" /v "http" /t REG_SZ /d "BrowserSelector" /f >nul
reg add "HKCU\Software\Classes\BrowserSelector\Capabilities\UrlAssociations" /v "https" /t REG_SZ /d "BrowserSelector" /f >nul

reg add "HKCU\Software\RegisteredApplications" /v "BrowserSelector" /t REG_SZ /d "Software\\Classes\\BrowserSelector\\Capabilities" /f >nul

:: Change default browser to custom browser selector
reg add "HKCU\Software\Classes\BrowserSelector\shell\open\command" /ve /t REG_SZ /d "wscript.exe \"%USERPROFILE%\\.local\\bin\\browser-selector.bat.vbs\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\http" /ve /t REG_SZ /d "BrowserSelector" /f >nul
reg add "HKCU\Software\Classes\https" /ve /t REG_SZ /d "BrowserSelector" /f >nul
