param(
    # Indicates the script is running from the installed copy.
    [switch]$InstalledMode,

    # Suppresses message boxes/prompts for Windows quiet uninstall.
    [switch]$Quiet,

    # Optional override used for tests or custom install paths.
    [string]$InstallDir = ""
)

$ErrorActionPreference = "Stop"

$appName = "Pulse HUD - FPS Overlay"
$appId = "PulseHUD-FPSOverlay"

function Get-FullPath {
    param([string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Assert-SafeInstallPath {
    param([string]$Path)

    $programsRoot = Get-FullPath (Join-Path $env:LOCALAPPDATA "Programs")
    $target = Get-FullPath $Path

    if (-not $target.StartsWith($programsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Caminho de instalacao inesperado: $target"
    }

    return $target
}

function Remove-ShortcutIfExists {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    }
}

if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    $InstallDir = Split-Path -Parent $PSScriptRoot
}

$installRoot = Assert-SafeInstallPath $InstallDir
$runtimeDir = Join-Path $installRoot ".runtime"
$pidFile = Join-Path $runtimeDir "overlay.pid"

# Stop the overlay first so files and tray icon can be removed cleanly.
if (Test-Path -LiteralPath $pidFile) {
    try {
        $overlayPid = [int](Get-Content -LiteralPath $pidFile -Raw).Trim()
        Stop-Process -Id $overlayPid -Force -ErrorAction SilentlyContinue
    } catch {}
}

# Remove any remaining PowerShell process that is running this installed app.
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object {
        $_.ProcessId -ne $PID -and
        $_.CommandLine -and
        $_.CommandLine.Contains($installRoot)
    } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }

# Remove Startup, Desktop and Start Menu shortcuts created by the installer.
Remove-ShortcutIfExists (Join-Path ([Environment]::GetFolderPath("Desktop")) "$appName.lnk")
Remove-ShortcutIfExists (Join-Path ([Environment]::GetFolderPath("Startup")) "$appName.lnk")

$startMenuDir = Join-Path ([Environment]::GetFolderPath("Programs")) $appName
if (Test-Path -LiteralPath $startMenuDir) {
    Remove-Item -LiteralPath $startMenuDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Remove the entry shown in Windows Settings > Apps.
$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$appId"
if (Test-Path -LiteralPath $uninstallKey) {
    Remove-Item -LiteralPath $uninstallKey -Recurse -Force
}

# Deleting the folder that contains the running uninstaller is safer when done
# by a short temporary cleanup script after this process exits.
$cleanupScript = Join-Path $env:TEMP ("pulse-hud-uninstall-" + [guid]::NewGuid().ToString("N") + ".ps1")
$escapedInstallRoot = $installRoot.Replace("'", "''")
$escapedCleanupScript = $cleanupScript.Replace("'", "''")

@"
Start-Sleep -Seconds 2
Remove-Item -LiteralPath '$escapedInstallRoot' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath '$escapedCleanupScript' -Force -ErrorAction SilentlyContinue
"@ | Set-Content -LiteralPath $cleanupScript -Encoding UTF8

Start-Process -FilePath "powershell.exe" -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-WindowStyle", "Hidden",
    "-File", "`"$cleanupScript`""
) -WindowStyle Hidden

if (-not $Quiet) {
    Write-Host "$appName foi desinstalado."
}
