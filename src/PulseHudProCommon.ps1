$script:PulseHudProRoot = Split-Path -Parent $PSScriptRoot
$script:PulseHudProRuntime = Join-Path $script:PulseHudProRoot ".runtime"
$script:PulseHudProProfilesPath = Join-Path $script:PulseHudProRoot "config\profiles.json"
New-Item -ItemType Directory -Force -Path $script:PulseHudProRuntime | Out-Null

$script:PulseHudTheme = @{
    Bg = "#070B10"
    Panel = "#101820"
    PanelAlt = "#111827"
    Border = "#1F3B57"
    Text = "#F8FAFC"
    Muted = "#9FB0C3"
    Accent = "#22D3EE"
    Accent2 = "#A78BFA"
    Danger = "#FB7185"
    Success = "#34D399"
}

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

function Set-ProWindowStyle {
    param(
        [System.Windows.Window]$Window,
        [string]$Title,
        [double]$Width,
        [double]$Height,
        [switch]$Topmost,
        [switch]$Overlay
    )

    $Window.Title = $Title
    $Window.Width = $Width
    $Window.Height = $Height
    $Window.MinWidth = [Math]::Min($Width, 520)
    $Window.MinHeight = [Math]::Min($Height, 360)
    $Window.WindowStartupLocation = "CenterScreen"
    $Window.Background = $script:PulseHudTheme.Bg
    $Window.Topmost = [bool]$Topmost

    if ($Overlay) {
        $Window.WindowStyle = "None"
        $Window.AllowsTransparency = $true
        $Window.ResizeMode = "CanResizeWithGrip"
        $Window.Opacity = 0.94
    }
}

function New-ProText {
    param(
        [string]$Text,
        [double]$Size,
        [string]$Weight = "Normal",
        [string]$Color = $script:PulseHudTheme.Text,
        [switch]$Mono
    )

    $block = New-Object System.Windows.Controls.TextBlock
    $block.Text = $Text
    $block.FontFamily = if ($Mono) { "Consolas" } else { "Segoe UI" }
    $block.FontSize = $Size
    $block.FontWeight = $Weight
    $block.Foreground = $Color
    $block.TextWrapping = "Wrap"
    return $block
}

function New-ProButton {
    param(
        [string]$Text,
        [double]$Width = 120,
        [double]$Height = 36,
        [string]$Kind = "Default"
    )

    $button = New-Object System.Windows.Controls.Button
    $button.Content = $Text
    $button.Width = $Width
    $button.Height = $Height
    $button.Margin = "0,0,8,8"
    $button.Padding = "10,4,10,4"
    $button.Foreground = $script:PulseHudTheme.Text
    $button.BorderThickness = 1
    $button.Cursor = [System.Windows.Input.Cursors]::Hand

    switch ($Kind) {
        "Primary" {
            $button.Background = "#0E7490"
            $button.BorderBrush = $script:PulseHudTheme.Accent
        }
        "Danger" {
            $button.Background = "#7F1D1D"
            $button.BorderBrush = $script:PulseHudTheme.Danger
        }
        default {
            $button.Background = $script:PulseHudTheme.PanelAlt
            $button.BorderBrush = $script:PulseHudTheme.Border
        }
    }

    return $button
}

function New-ProPanel {
    param(
        [object]$Child,
        [string]$Padding = "12",
        [string]$Margin = "0,0,0,12"
    )

    $border = New-Object System.Windows.Controls.Border
    $border.Background = $script:PulseHudTheme.Panel
    $border.BorderBrush = $script:PulseHudTheme.Border
    $border.BorderThickness = 1
    $border.CornerRadius = 6
    $border.Padding = $Padding
    $border.Margin = $Margin
    $border.Child = $Child
    return $border
}
