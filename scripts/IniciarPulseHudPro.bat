@echo off
cd /d "%~dp0\.."
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "%cd%\src\PulseHudPro.ps1"
