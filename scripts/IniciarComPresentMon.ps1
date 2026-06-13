param(
    # Executable name to capture, for example game.exe.
    [Parameter(Mandatory = $true)]
    [string]$ProcessName,

    # Overlay initial position.
    [int]$X = 20,
    [int]$Y = 20
)

$ErrorActionPreference = "Stop"

# Start PresentMon writing a CSV, then launch the overlay reading that CSV.
$root = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $root ".runtime"
$presentMon = Join-Path $root "tools\PresentMon.exe"
$csv = Join-Path $runtime "presentmon.csv"

New-Item -ItemType Directory -Force -Path $runtime | Out-Null

if (-not (Test-Path -LiteralPath $presentMon)) {
    throw "PresentMon nao foi encontrado. Rode scripts\BaixarPresentMon.ps1 primeiro."
}

# Fresh CSV avoids mixing old frames with the new capture.
Remove-Item -LiteralPath $csv -ErrorAction SilentlyContinue

# PresentMon may need elevation to start the ETW session.
$pmArgs = @(
    "--process_name", $ProcessName,
    "--output_file", $csv,
    "--stop_existing_session",
    "--restart_as_admin"
)

Start-Process -FilePath $presentMon -ArgumentList $pmArgs -WindowStyle Minimized

Start-Sleep -Seconds 2

# The overlay calculates FPS from the PresentMon CSV.
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File (Join-Path $root "src\OverlayLeve.ps1") -X $X -Y $Y -PresentMonCsv $csv
