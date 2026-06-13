$ErrorActionPreference = "Stop"

# Creates a Windows desktop shortcut for the all-in-one Pulse HUD Pro dashboard.
$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $root "bin\PulseHUDPro.exe"
$shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Pulse HUD Pro.lnk"

if (-not (Test-Path -LiteralPath $target)) {
    & (Join-Path $root "scripts\CompilarExecutaveis.ps1") | Out-Host
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $target
$shortcut.Arguments = ""
$shortcut.WorkingDirectory = $root
$shortcut.Description = "Inicia o Pulse HUD Pro"
$icon = Join-Path $root "assets\logo.ico"
$shortcut.IconLocation = if (Test-Path -LiteralPath $icon) { $icon } else { "$env:SystemRoot\System32\perfmon.exe,0" }
$shortcut.Save()

Write-Host "Atalho criado em: $shortcutPath"
