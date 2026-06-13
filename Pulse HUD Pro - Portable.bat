@echo off
cd /d "%~dp0"
if not exist "bin\PulseHUDPro.exe" (
    echo PulseHUDPro.exe nao encontrado.
    echo Extraia o ZIP inteiro antes de abrir o modo portatil.
    pause
    exit /b 1
)
start "" "%cd%\bin\PulseHUDPro.exe"
