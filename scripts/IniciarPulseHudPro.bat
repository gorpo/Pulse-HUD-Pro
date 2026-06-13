@echo off
cd /d "%~dp0\.."
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%cd%\src\PulseHudPro.ps1"
