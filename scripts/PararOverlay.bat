@echo off
rem Stops the running overlay by the PID file created at startup.
set "ROOT=%~dp0.."
set "PIDFILE=%ROOT%\.runtime\overlay.pid"

if exist "%PIDFILE%" (
    rem Normal path: stop the exact process that wrote overlay.pid.
    for /f "usebackq" %%p in ("%PIDFILE%") do taskkill /PID %%p /F >nul 2>&1
    del "%PIDFILE%" >nul 2>&1
)

rem Fallback for launcher-based starts or stale PID files.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$root=[IO.Path]::GetFullPath('%ROOT%'); $self=$PID; Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.ProcessId -ne $self -and $_.CommandLine -and $_.CommandLine.Contains($root) -and $_.CommandLine.Contains('OverlayLeve.ps1') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>&1
