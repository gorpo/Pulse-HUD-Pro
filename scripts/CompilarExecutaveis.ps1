$ErrorActionPreference = "Stop"

# Builds the final user-facing .exe launchers with the project icon.
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root "src\Launcher.cs"
$bin = Join-Path $root "bin"
$icon = Join-Path $root "assets\logo.ico"
$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (-not (Test-Path -LiteralPath $csc)) {
    $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe"
}

if (-not (Test-Path -LiteralPath $csc)) {
    throw "Compilador csc.exe do .NET Framework nao encontrado."
}

New-Item -ItemType Directory -Force -Path $bin | Out-Null

$mainExe = Join-Path $bin "PulseHUD.exe"
$refs = @(
    "/r:System.dll",
    "/r:System.Core.dll",
    "/r:System.Windows.Forms.dll",
    "/r:System.Drawing.dll"
)

$args = @(
    "/nologo",
    "/target:winexe",
    "/platform:anycpu",
    "/optimize+",
    "/out:$mainExe"
) + $refs

if (Test-Path -LiteralPath $icon) {
    $args += "/win32icon:$icon"
}

$args += $src

& $csc @args

if ($LASTEXITCODE -ne 0) {
    throw "Falha ao compilar launchers."
}

# Same binary, different file names; Launcher.cs chooses behavior by exe name.
Copy-Item -LiteralPath $mainExe -Destination (Join-Path $bin "PulseHUDConfig.exe") -Force
Copy-Item -LiteralPath $mainExe -Destination (Join-Path $bin "PulseHUDInstall.exe") -Force
Copy-Item -LiteralPath $mainExe -Destination (Join-Path $bin "PulseHUDUninstall.exe") -Force
Copy-Item -LiteralPath $mainExe -Destination (Join-Path $bin "PulseHUDPro.exe") -Force

Get-ChildItem -LiteralPath $bin -Filter *.exe | Select-Object FullName, Length
