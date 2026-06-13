$ErrorActionPreference = "Stop"

# Downloads the latest PresentMon release so FPS capture can work offline later.
$root = Split-Path -Parent $PSScriptRoot
$toolsDir = Join-Path $root "tools"
New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null

# GitHub's API gives us the current release without hard-coding a version.
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/GameTechDev/PresentMon/releases/latest" -Headers @{ "User-Agent" = "OverlayLeve" }
$asset = $release.assets |
    Where-Object { $_.name -match "PresentMon.*x64.*\.exe$" } |
    Select-Object -First 1

if (-not $asset) {
    throw "Nao encontrei um executavel x64 do PresentMon na ultima release."
}

# Keep the original versioned file and a stable PresentMon.exe copy.
$target = Join-Path $toolsDir $asset.name
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $target

$stablePath = Join-Path $toolsDir "PresentMon.exe"
Copy-Item -LiteralPath $target -Destination $stablePath -Force

Write-Host "PresentMon baixado em: $stablePath"
