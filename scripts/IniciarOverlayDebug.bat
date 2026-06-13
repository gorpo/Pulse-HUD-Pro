@echo off
rem Starts the overlay with a visible PowerShell console for troubleshooting.
set "ROOT=%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%ROOT%\src\OverlayLeve.ps1" -NoClickThrough
