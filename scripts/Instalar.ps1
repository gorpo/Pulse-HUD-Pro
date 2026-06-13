param(
    # Per-user install location. HKCU uninstall entries do not need admin rights.
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "Programs\Pulse HUD - FPS Overlay"),

    # Useful for scripted installs where desktop shortcuts are not wanted.
    [switch]$NoDesktopShortcut
)

$ErrorActionPreference = "Stop"

# The installer is intentionally simple: copy the project, create shortcuts, and
# register a standard Windows uninstall entry for the current user.
$sourceRoot = Split-Path -Parent $PSScriptRoot
$appName = "Pulse HUD - FPS Overlay"
$publisher = "gorpo"
$version = "0.2.0"
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
        throw "Por seguranca, instale dentro de $programsRoot"
    }

    return $target
}

function New-Shortcut {
    param(
        [string]$Path,
        [string]$TargetPath,
        [string]$Arguments,
        [string]$WorkingDirectory,
        [string]$IconLocation,
        [string]$Description
    )

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.IconLocation = $IconLocation
    $shortcut.Description = $Description
    $shortcut.Save()
}

$installRoot = Assert-SafeInstallPath $InstallDir
$iconPath = Join-Path $installRoot "assets\logo.ico"
$sourceCompiler = Join-Path $sourceRoot "scripts\CompilarExecutaveis.ps1"

# Make sure the final executables exist before copying/installing.
if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot "bin\PulseHUD.exe"))) {
    & $sourceCompiler | Out-Host
}

$runExe = Join-Path $installRoot "bin\PulseHUD.exe"
$configExe = Join-Path $installRoot "bin\PulseHUDConfig.exe"
$uninstallExe = Join-Path $installRoot "bin\PulseHUDUninstall.exe"

Write-Host "Instalando $appName em: $installRoot"

# Stop a previous installed copy before overwriting files.
$oldPidFile = Join-Path $installRoot ".runtime\overlay.pid"
if (Test-Path -LiteralPath $oldPidFile) {
    try {
        $oldPid = [int](Get-Content -LiteralPath $oldPidFile -Raw).Trim()
        Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
    } catch {}
}

New-Item -ItemType Directory -Force -Path $installRoot | Out-Null

# Copy project files, skipping only development/runtime folders that should not
# be part of the installed app.
Get-ChildItem -LiteralPath $sourceRoot -Force |
    Where-Object { $_.Name -notin @(".git", ".runtime", "release") } |
    ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $installRoot -Recurse -Force
    }

if (-not (Test-Path -LiteralPath $iconPath)) {
    $iconPath = "$env:SystemRoot\System32\perfmon.exe,0"
}

# Desktop shortcut launches the hidden VBS so no PowerShell window appears.
if (-not $NoDesktopShortcut) {
    $desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "$appName.lnk"
New-Shortcut `
    -Path $desktopShortcut `
        -TargetPath $runExe `
        -Arguments "" `
        -WorkingDirectory $installRoot `
        -IconLocation $iconPath `
        -Description "Inicia o $appName"
}

# Start Menu entries make the app easy to open, configure and uninstall.
$startMenuDir = Join-Path ([Environment]::GetFolderPath("Programs")) $appName
New-Item -ItemType Directory -Force -Path $startMenuDir | Out-Null

New-Shortcut `
    -Path (Join-Path $startMenuDir "$appName.lnk") `
    -TargetPath $runExe `
    -Arguments "" `
    -WorkingDirectory $installRoot `
    -IconLocation $iconPath `
    -Description "Inicia o $appName"

New-Shortcut `
    -Path (Join-Path $startMenuDir "Configurar $appName.lnk") `
    -TargetPath $configExe `
    -Arguments "" `
    -WorkingDirectory $installRoot `
    -IconLocation $iconPath `
    -Description "Abre as configuracoes do $appName"

New-Shortcut `
    -Path (Join-Path $startMenuDir "Desinstalar $appName.lnk") `
    -TargetPath $uninstallExe `
    -Arguments "" `
    -WorkingDirectory $installRoot `
    -IconLocation $iconPath `
    -Description "Desinstala o $appName"

# This HKCU location is read by Windows Settings > Apps > Installed apps and by
# the classic Programs and Features view for per-user applications.
$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$appId"
New-Item -Path $uninstallKey -Force | Out-Null

$uninstallCommand = "`"$uninstallExe`""
$quietUninstallCommand = "`"$uninstallExe`" -Quiet"
$estimatedSizeKb = [int](([long](Get-ChildItem -LiteralPath $installRoot -Recurse -File -Force | Measure-Object -Property Length -Sum).Sum + 1023) / 1024)

Set-ItemProperty -Path $uninstallKey -Name "DisplayName" -Value $appName
Set-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value $version
Set-ItemProperty -Path $uninstallKey -Name "Publisher" -Value $publisher
Set-ItemProperty -Path $uninstallKey -Name "InstallLocation" -Value $installRoot
Set-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value $iconPath
Set-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value $uninstallCommand
Set-ItemProperty -Path $uninstallKey -Name "QuietUninstallString" -Value $quietUninstallCommand
Set-ItemProperty -Path $uninstallKey -Name "EstimatedSize" -Type DWord -Value $estimatedSizeKb
Set-ItemProperty -Path $uninstallKey -Name "NoModify" -Type DWord -Value 1
Set-ItemProperty -Path $uninstallKey -Name "NoRepair" -Type DWord -Value 1

Write-Host "$appName instalado."
Write-Host "Ele deve aparecer em Configuracoes > Aplicativos > Aplicativos instalados."
