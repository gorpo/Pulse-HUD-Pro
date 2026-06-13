$script:PulseHudProRoot = Split-Path -Parent $PSScriptRoot
$script:PulseHudProRuntime = Join-Path $script:PulseHudProRoot ".runtime"
$script:PulseHudProProfilesPath = Join-Path $script:PulseHudProRoot "config\profiles.json"
New-Item -ItemType Directory -Force -Path $script:PulseHudProRuntime | Out-Null

function Get-ProProfiles {
    if (-not (Test-Path -LiteralPath $script:PulseHudProProfilesPath)) {
        throw "Arquivo nao encontrado: $script:PulseHudProProfilesPath"
    }
    Get-Content -LiteralPath $script:PulseHudProProfilesPath -Raw | ConvertFrom-Json
}

function Resolve-ProPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if ([System.IO.Path]::IsPathRooted($expanded)) { return $expanded }
    return Join-Path $script:PulseHudProRoot $expanded
}

function Write-ProLog {
    param([string]$Name, [string]$Message)

    $log = Join-Path $script:PulseHudProRuntime "$Name.log"
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath $log -Value "[$stamp] $Message" -Encoding UTF8
}

function Start-ProConfiguredApp {
    param([string]$Path)

    $resolved = Resolve-ProPath $Path
    if ([string]::IsNullOrWhiteSpace($resolved) -or -not (Test-Path -LiteralPath $resolved)) { return $false }
    Start-Process -FilePath $resolved
    return $true
}

function Stop-ProProcesses {
    param([object[]]$Names)

    foreach ($name in @($Names)) {
        if ([string]::IsNullOrWhiteSpace([string]$name)) { continue }
        Get-Process -Name ([string]$name) -ErrorAction SilentlyContinue | ForEach-Object {
            try { $_.CloseMainWindow() | Out-Null } catch {}
            Start-Sleep -Milliseconds 250
            if (-not $_.HasExited) {
                try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch {}
            }
        }
    }
}

function Set-ProProcessPriority {
    param([string]$ProcessName, [string]$Priority)

    if ([string]::IsNullOrWhiteSpace($ProcessName) -or [string]::IsNullOrWhiteSpace($Priority)) { return }
    Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | ForEach-Object {
        try { $_.PriorityClass = $Priority } catch {}
    }
}

function Get-ProPowerSchemeGuid {
    $line = (& powercfg /getactivescheme 2>$null) -join " "
    if ($line -match "([A-Fa-f0-9-]{36})") { return $matches[1] }
    return ""
}

function Set-ProPowerPlan {
    param([string]$Plan)

    switch -Regex ($Plan) {
        "^high$|alto|performance" { & powercfg /setactive SCHEME_MIN 2>$null | Out-Null; return }
        "^balanced$|equilibr" { & powercfg /setactive SCHEME_BALANCED 2>$null | Out-Null; return }
        "^power|econom" { & powercfg /setactive SCHEME_MAX 2>$null | Out-Null; return }
        "^[A-Fa-f0-9-]{36}$" { & powercfg /setactive $Plan 2>$null | Out-Null; return }
    }
}
