$ErrorActionPreference = "Stop"

# Creates a Windows desktop shortcut that launches the hidden VBS entry point.
$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $root "bin\PulseHUD.exe"
$shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Pulse HUD - FPS Overlay.lnk"

if (-not (Test-Path -LiteralPath $target)) {
    & (Join-Path $root "scripts\CompilarExecutaveis.ps1") | Out-Host
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $target
$shortcut.Arguments = ""
$shortcut.WorkingDirectory = $root
$shortcut.Description = "Inicia o Pulse HUD - FPS Overlay"
$icon = Join-Path $root "assets\logo.ico"
$shortcut.IconLocation = if (Test-Path -LiteralPath $icon) { $icon } else { "$env:SystemRoot\System32\perfmon.exe,0" }
$shortcut.Save()

Write-Host "Atalho criado em: $shortcutPath"
