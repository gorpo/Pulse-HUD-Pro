@echo off
rem Uninstalls the installed copy of Pulse HUD for the current Windows user.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Desinstalar.ps1" -InstalledMode
pause
