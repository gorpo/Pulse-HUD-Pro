@echo off
cd /d "%~dp0\.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%cd%\src\PulseHudPro.ps1"
pause
