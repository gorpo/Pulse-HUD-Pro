$ErrorActionPreference = "Stop"

# Creates a distributable ZIP without requiring GitHub tools.
$root = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $root "release"
$zipPath = Join-Path $releaseDir "Pulse-HUD-FPS-Overlay.zip"
$tempDir = Join-Path $env:TEMP ("pulse-hud-release-" + [guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

# Release packages expose .exe entry points. Build them before zipping.
& (Join-Path $root "scripts\CompilarExecutaveis.ps1") | Out-Host

try {
    # Copy only files useful to users; skip Git internals and runtime state.
    Get-ChildItem -LiteralPath $root -Force |
        Where-Object { $_.Name -notin @(".git", ".runtime", "release") } |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $tempDir -Recurse -Force
        }

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $tempDir "*") -DestinationPath $zipPath -Force
    Write-Host "Release ZIP criado em: $zipPath"
} finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
