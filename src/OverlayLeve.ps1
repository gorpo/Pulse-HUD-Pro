param(
    # Optional path to a JSON settings file. Defaults to config/settings.json.
    [string]$ConfigPath = "",

    # Optional PresentMon CSV source used to calculate real game FPS.
    [string]$PresentMonCsv = "",

    # Optional plain text FPS source. The last numeric value is displayed.
    [string]$FpsFile = "$env:TEMP\overlay_fps.txt",

    # Optional startup position override used by helper scripts.
    [Nullable[int]]$X = $null,

    # Optional startup position override used by helper scripts.
    [Nullable[int]]$Y = $null,

    # Keeps compatibility with the old debug launcher by forcing mouse access.
    [switch]$NoClickThrough,

    # Disables the tray icon, useful for automated tests.
    [switch]$NoTray
)

# Keep runtime files out of the repository and close to the project folder.
$ErrorActionPreference = "Continue"
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:RuntimeDir = Join-Path $script:ProjectRoot ".runtime"
New-Item -ItemType Directory -Force -Path $script:RuntimeDir | Out-Null

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $script:ProjectRoot "config\settings.json"
}

$script:PidPath = Join-Path $script:RuntimeDir "overlay.pid"
$script:LogPath = Join-Path $script:RuntimeDir "overlay.log"
Set-Content -LiteralPath $script:PidPath -Value $PID -Encoding ASCII

# Small file logger used because the normal launcher runs without a console.
function Write-OverlayLog {
    param([string]$Message)

    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath $script:LogPath -Value "[$stamp] $Message" -Encoding UTF8
}

# Built-in defaults let the app recreate config/settings.json on first run.
function Get-DefaultSettings {
    [pscustomobject]@{
        AppName = "Pulse HUD - FPS Overlay"
        Mode = "Overlay"
        X = 20
        Y = 20
        Width = 224
        Height = 116
        IntervalMs = 1000
        BackgroundColor = "#0D0F12"
        TextColor = "#FFFFFF"
        LabelColor = "#DCDCDC"
        AccentColor = "#7DD3FC"
        Opacity = 0.86
        FontSize = 16
        LabelFontSize = 12
        ClickThrough = $false
        ShowInTaskbar = $false
        StartWithWindows = $false
        ToggleHotkey = "Ctrl+Alt+O"
        FpsFile = "$env:TEMP\overlay_fps.txt"
        PresentMonCsv = ""
    }
}

# Persist settings in JSON so users can edit them by hand or through the panel.
function Save-Settings {
    param($Settings)

    $dir = Split-Path -Parent $ConfigPath
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $Settings | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
}

# Load settings, merge any missing new fields, and expand environment variables.
function Get-Settings {
    $defaults = Get-DefaultSettings

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        Save-Settings $defaults
        return $defaults
    }

    try {
        $loaded = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    } catch {
        Write-OverlayLog "Invalid settings. Using defaults: $($_.Exception.Message)"
        return $defaults
    }

    foreach ($prop in $defaults.PSObject.Properties.Name) {
        if (-not ($loaded.PSObject.Properties.Name -contains $prop)) {
            $loaded | Add-Member -NotePropertyName $prop -NotePropertyValue $defaults.$prop
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($PresentMonCsv)) { $loaded.PresentMonCsv = $PresentMonCsv }
    if (-not [string]::IsNullOrWhiteSpace($FpsFile)) { $loaded.FpsFile = $FpsFile }
    if ($null -ne $X) { $loaded.X = [int]$X }
    if ($null -ne $Y) { $loaded.Y = [int]$Y }
    if ($NoClickThrough) { $loaded.ClickThrough = $false }
    $loaded.FpsFile = [Environment]::ExpandEnvironmentVariables($loaded.FpsFile)
    $loaded.PresentMonCsv = [Environment]::ExpandEnvironmentVariables($loaded.PresentMonCsv)

    return $loaded
}

# Convert a hex color string into a WPF brush with independent alpha.
function Convert-Brush {
    param(
        [string]$Color,
        [double]$Alpha = 1.0
    )

    try {
        $mediaColor = [System.Windows.Media.ColorConverter]::ConvertFromString($Color)
        $mediaColor.A = [byte]([Math]::Max(0, [Math]::Min(255, 255 * $Alpha)))
        return [System.Windows.Media.SolidColorBrush]::new($mediaColor)
    } catch {
        return [System.Windows.Media.Brushes]::Black
    }
}

# Convert strings like Ctrl+Alt+O into the Win32 modifier/key values.
function Parse-Hotkey {
    param([string]$Text)

    $modifier = 0
    $keyPart = ""

    foreach ($part in ($Text -split "\+")) {
        $clean = $part.Trim()
        switch -Regex ($clean) {
            "^(Ctrl|Control)$" { $modifier = $modifier -bor 0x0002; continue }
            "^Alt$" { $modifier = $modifier -bor 0x0001; continue }
            "^Shift$" { $modifier = $modifier -bor 0x0004; continue }
            "^Win(dows)?$" { $modifier = $modifier -bor 0x0008; continue }
            default { $keyPart = $clean.ToUpperInvariant() }
        }
    }

    if ([string]::IsNullOrWhiteSpace($keyPart)) { $keyPart = "O" }
    try {
        $key = [System.Enum]::Parse([System.Windows.Forms.Keys], $keyPart, $true)
    } catch {
        $key = [System.Windows.Forms.Keys]::O
    }

    [pscustomobject]@{
        Modifiers = $modifier
        Key = [int]$key
    }
}

# WPF draws the overlay; WinForms provides tray icons and keyboard constants.
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# Native calls are needed for click-through windows and global hotkeys.
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class PulseHudNative {
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_TRANSPARENT = 0x00000020;
    public const int WS_EX_TOOLWINDOW = 0x00000080;
    public const int WS_EX_APPWINDOW = 0x00040000;
    public const int WM_HOTKEY = 0x0312;
    private const uint SWP_NOSIZE = 0x0001;
    private const uint SWP_NOMOVE = 0x0002;
    private const uint SWP_NOZORDER = 0x0004;
    private const uint SWP_NOACTIVATE = 0x0010;
    private const uint SWP_FRAMECHANGED = 0x0020;

    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll")]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    public static void SetClickThrough(IntPtr hwnd, bool enabled, bool showInTaskbar) {
        int style = GetWindowLong(hwnd, GWL_EXSTYLE);
        if (enabled) style = style | WS_EX_TRANSPARENT;
        else style = style & ~WS_EX_TRANSPARENT;

        if (showInTaskbar) {
            style = (style & ~WS_EX_TOOLWINDOW) | WS_EX_APPWINDOW;
        } else {
            style = (style | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW;
        }

        SetWindowLong(hwnd, GWL_EXSTYLE, style);
        SetWindowPos(hwnd, IntPtr.Zero, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
    }
}
"@

$script:Settings = Get-Settings
Write-OverlayLog "Starting $($script:Settings.AppName). PID=$PID"

# Shared state used by the timer, tray icon, hotkey hook, and window events.
$script:CpuCounter = $null
$script:CpuPerfCounter = $null
$script:GpuCounters = @()
$script:GpuMemoryCounters = @()
$script:ComputerInfo = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
$script:CpuBaseGhz = 0.0
$script:GpuTotalBytes = 0.0
$script:LastConfigWrite = if (Test-Path -LiteralPath $ConfigPath) { (Get-Item -LiteralPath $ConfigPath).LastWriteTimeUtc } else { [datetime]::MinValue }
$script:HotkeyId = 8301
$script:WindowHandle = [IntPtr]::Zero
$script:NotifyIcon = $null
$script:DialogStarted = $false

# CPU base clock is used to show an approximate GHz value beside CPU usage.
try {
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    if ($cpu.MaxClockSpeed) { $script:CpuBaseGhz = [double]$cpu.MaxClockSpeed / 1000 }
} catch {}

# Total CPU usage.
try {
    $script:CpuCounter = New-Object System.Diagnostics.PerformanceCounter("Processor", "% Processor Time", "_Total")
    [void]$script:CpuCounter.NextValue()
} catch {
    Write-OverlayLog "CPU usage counter unavailable: $($_.Exception.Message)"
}

# CPU performance counter, when available, improves the GHz estimate.
try {
    $script:CpuPerfCounter = New-Object System.Diagnostics.PerformanceCounter("Processor Information", "% Processor Performance", "_Total")
    [void]$script:CpuPerfCounter.NextValue()
} catch {
    Write-OverlayLog "CPU performance counter unavailable: $($_.Exception.Message)"
}

# GPU 3D usage comes from native Windows GPU Engine counters.
try {
    $gpuCategory = New-Object System.Diagnostics.PerformanceCounterCategory("GPU Engine")
    $gpuInstances = $gpuCategory.GetInstanceNames() | Where-Object { $_ -like "*engtype_3D*" }
    foreach ($instance in $gpuInstances) {
        $counter = New-Object System.Diagnostics.PerformanceCounter("GPU Engine", "Utilization Percentage", $instance)
        [void]$counter.NextValue()
        $script:GpuCounters += $counter
    }
} catch {
    Write-OverlayLog "GPU usage counters unavailable: $($_.Exception.Message)"
}

# Dedicated GPU memory usage, when exposed by the driver/Windows build.
try {
    $memCategory = New-Object System.Diagnostics.PerformanceCounterCategory("GPU Adapter Memory")
    foreach ($instance in $memCategory.GetInstanceNames()) {
        $counter = New-Object System.Diagnostics.PerformanceCounter("GPU Adapter Memory", "Dedicated Usage", $instance)
        [void]$counter.NextValue()
        $script:GpuMemoryCounters += $counter
    }
} catch {
    Write-OverlayLog "GPU memory counters unavailable: $($_.Exception.Message)"
}

# AdapterRAM is used only as contextual data; usage is read from counters above.
try {
    $script:GpuTotalBytes = [double]((Get-CimInstance Win32_VideoController | Measure-Object -Property AdapterRAM -Sum).Sum)
} catch {}

# Clamp and format a percentage for compact overlay output.
function Format-Percent {
    param([double]$Value)
    return ("{0:N0}%" -f [Math]::Max(0, [Math]::Min(100, $Value)))
}

# CPU displays percentage plus approximate GHz, matching RAM's two-value style.
function Split-MetricText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text) -or $Text -eq "--") {
        return [pscustomobject]@{ Primary = "--"; Secondary = "" }
    }

    $parts = $Text -split "\s{2,}", 2
    if ($parts.Count -eq 1) {
        return [pscustomobject]@{ Primary = $parts[0]; Secondary = "" }
    }

    return [pscustomobject]@{ Primary = $parts[0]; Secondary = $parts[1] }
}

# CPU displays percentage plus approximate GHz, matching RAM's two-value style.
function Get-CpuText {
    if ($null -eq $script:CpuCounter) { return "--" }

    try {
        $pct = $script:CpuCounter.NextValue()
        $ghz = $script:CpuBaseGhz

        if ($null -ne $script:CpuPerfCounter -and $script:CpuBaseGhz -gt 0) {
            $perf = $script:CpuPerfCounter.NextValue()
            if ($perf -gt 0) { $ghz = $script:CpuBaseGhz * ($perf / 100) }
        }

        if ($ghz -gt 0) {
            return ("{0}  {1:N2} GHz" -f (Format-Percent $pct), $ghz)
        }

        return Format-Percent $pct
    } catch {
        return "--"
    }
}

# RAM displays percentage plus used GB.
function Get-RamText {
    try {
        $total = [double]$script:ComputerInfo.TotalPhysicalMemory
        $available = [double]$script:ComputerInfo.AvailablePhysicalMemory
        if ($total -le 0) { return "--" }

        $used = $total - $available
        return ("{0:N0}%  {1:N1} GB" -f (($used / $total) * 100), ($used / 1GB))
    } catch {
        return "--"
    }
}

# GPU displays percentage plus dedicated memory usage when available.
function Get-GpuText {
    try {
        $usage = $null
        if ($script:GpuCounters.Count -gt 0) {
            $sum = 0.0
            foreach ($counter in $script:GpuCounters) { $sum += $counter.NextValue() }
            $usage = Format-Percent $sum
        }

        $memBytes = 0.0
        foreach ($counter in $script:GpuMemoryCounters) { $memBytes += $counter.NextValue() }

        if ($memBytes -gt 0) {
            $usageText = if ($usage) { $usage } else { "--" }
            return ("{0}  {1:N1} GB" -f $usageText, ($memBytes / 1GB))
        }

        if ($usage) { return $usage }
        return "--"
    } catch {
        return "--"
    }
}

# Read the last numeric value from a simple FPS text file.
function Read-LastNumericValue {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $line = Get-Content -LiteralPath $Path -Tail 1 -ErrorAction Stop
        if ($line -match "([0-9]+([\.,][0-9]+)?)") {
            return [double]($matches[1].Replace(",", "."))
        }
    } catch {}
    return $null
}

# Convert frame time values from PresentMon into FPS.
function Convert-MsToFps {
    param([double[]]$Values)

    $valid = @($Values | Where-Object { $_ -gt 0 -and $_ -lt 10000 })
    if ($valid.Count -eq 0) { return $null }
    $avgMs = ($valid | Measure-Object -Average).Average
    if ($avgMs -le 0) { return $null }
    return 1000 / $avgMs
}

# Read a PresentMon CSV and infer FPS from known FPS or frame-time columns.
function Get-FpsFromPresentMonCsv {
    $path = $script:Settings.PresentMonCsv
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    if (-not (Test-Path -LiteralPath $path)) { return $null }

    try {
        $lines = Get-Content -LiteralPath $path -Tail 120 -ErrorAction Stop
        if ($lines.Count -lt 2) { return $null }

        $header = Get-Content -LiteralPath $path -TotalCount 1 -ErrorAction Stop
        $rows = @($lines | Where-Object { $_ -and $_ -ne $header } | ConvertFrom-Csv -Header ($header -split ","))
        if ($rows.Count -eq 0) { return $null }

        $columns = @($rows[0].PSObject.Properties.Name)
        $fpsColumn = @("FPS", "FPS-Display", "FPS-Presents", "FPS-App") |
            Where-Object { $columns -contains $_ } |
            Select-Object -First 1

        if ($fpsColumn) {
            $fpsValues = foreach ($row in $rows) {
                $value = 0.0
                if ([double]::TryParse(([string]$row.$fpsColumn).Replace(",", "."), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)) {
                    if ($value -gt 0 -and $value -lt 2000) { $value }
                }
            }
            if (@($fpsValues).Count -gt 0) { return ($fpsValues | Measure-Object -Average).Average }
        }

        $msColumn = @("MsBetweenPresents", "MsBetweenDisplayChange", "Displayed Frame Time", "Presented Frame Time", "MsUntilDisplayed") |
            Where-Object { $columns -contains $_ } |
            Select-Object -First 1

        if (-not $msColumn) {
            $msColumn = $columns |
                Where-Object { $_ -match "ms.*between.*present" -or $_ -match "display.*frame.*time" -or $_ -match "presented.*frame.*time" } |
                Select-Object -First 1
        }

        if (-not $msColumn) { return $null }

        $msValues = foreach ($row in $rows) {
            $value = 0.0
            if ([double]::TryParse(([string]$row.$msColumn).Replace(",", "."), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)) {
                $value
            }
        }

        return Convert-MsToFps @($msValues)
    } catch {
        return $null
    }
}

# FPS intentionally stays as one number only.
function Get-FpsText {
    $fps = Get-FpsFromPresentMonCsv
    if ($null -eq $fps) { $fps = Read-LastNumericValue $script:Settings.FpsFile }
    if ($null -eq $fps) { return "--" }
    return ("{0:N0}" -f $fps)
}

# Helper for consistent WPF text blocks.
function New-TextBlock {
    param([string]$Text, [double]$Size, [string]$Weight, [string]$Color)

    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontFamily = "Segoe UI"
    $tb.FontSize = $Size
    $tb.FontWeight = $Weight
    $tb.Foreground = Convert-Brush $Color 1
    $tb.VerticalAlignment = "Center"
    return $tb
}

# Adds one metric label/value row to the overlay grid.
function Add-MetricRow {
    param(
        [System.Windows.Controls.Grid]$Grid,
        [int]$Row,
        [string]$Label,
        [System.Windows.Controls.TextBlock]$PrimaryBlock,
        [System.Windows.Controls.TextBlock]$SecondaryBlock
    )

    $labelBlock = New-TextBlock $Label $script:Settings.LabelFontSize "SemiBold" $script:Settings.LabelColor
    $labelBlock.Opacity = 0.86
    [System.Windows.Controls.Grid]::SetRow($labelBlock, $Row)
    [System.Windows.Controls.Grid]::SetColumn($labelBlock, 0)
    [void]$Grid.Children.Add($labelBlock)

    $PrimaryBlock.FontFamily = "Consolas"
    $PrimaryBlock.FontSize = $script:Settings.FontSize
    $PrimaryBlock.FontWeight = "Bold"
    $PrimaryBlock.Foreground = Convert-Brush $script:Settings.TextColor 1
    $PrimaryBlock.HorizontalAlignment = "Right"
    [System.Windows.Controls.Grid]::SetRow($PrimaryBlock, $Row)
    [System.Windows.Controls.Grid]::SetColumn($PrimaryBlock, 1)
    [void]$Grid.Children.Add($PrimaryBlock)

    $SecondaryBlock.FontFamily = "Consolas"
    $SecondaryBlock.FontSize = [Math]::Max(10, [double]$script:Settings.FontSize - 1)
    $SecondaryBlock.FontWeight = "SemiBold"
    $SecondaryBlock.Foreground = Convert-Brush $script:Settings.TextColor 0.86
    $SecondaryBlock.HorizontalAlignment = "Right"
    [System.Windows.Controls.Grid]::SetRow($SecondaryBlock, $Row)
    [System.Windows.Controls.Grid]::SetColumn($SecondaryBlock, 2)
    [void]$Grid.Children.Add($SecondaryBlock)

    return $labelBlock
}

# Create or remove the Startup shortcut based on settings.
function Update-StartupShortcut {
    try {
        $startupDir = [Environment]::GetFolderPath("Startup")
        $shortcutPath = Join-Path $startupDir "$($script:Settings.AppName).lnk"
        $target = Join-Path $script:ProjectRoot "scripts\IniciarOverlay.vbs"
        $icon = Join-Path $script:ProjectRoot "assets\logo.ico"

        if ($script:Settings.StartWithWindows) {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = "wscript.exe"
            $shortcut.Arguments = "`"$target`""
            $shortcut.WorkingDirectory = $script:ProjectRoot
            $shortcut.IconLocation = if (Test-Path -LiteralPath $icon) { $icon } else { "$env:SystemRoot\System32\perfmon.exe,0" }
            $shortcut.Save()
        } elseif (Test-Path -LiteralPath $shortcutPath) {
            Remove-Item -LiteralPath $shortcutPath -Force
        }
    } catch {
        Write-OverlayLog "Startup shortcut update failed: $($_.Exception.Message)"
    }
}

# Apply visual/config changes without restarting the overlay.
function Apply-SettingsToWindow {
    $showInTaskbar = [bool]$script:Settings.ShowInTaskbar -or $script:Settings.Mode -eq "Taskbar"

    $window.Title = $script:Settings.AppName
    $window.Width = [double]$script:Settings.Width
    $window.Height = [double]$script:Settings.Height
    $window.Left = [double]$script:Settings.X
    $window.Top = [double]$script:Settings.Y
    $window.ShowInTaskbar = $showInTaskbar
    $border.Background = Convert-Brush $script:Settings.BackgroundColor ([double]$script:Settings.Opacity)
    $border.BorderBrush = Convert-Brush $script:Settings.AccentColor 0.55

    foreach ($label in $script:LabelBlocks) {
        $label.FontSize = [double]$script:Settings.LabelFontSize
        $label.Foreground = Convert-Brush $script:Settings.LabelColor 1
    }

    foreach ($value in @($fpsPrimary, $cpuPrimary, $gpuPrimary, $ramPrimary)) {
        $value.FontSize = [double]$script:Settings.FontSize
        $value.Foreground = Convert-Brush $script:Settings.TextColor 1
    }

    foreach ($value in @($fpsSecondary, $cpuSecondary, $gpuSecondary, $ramSecondary)) {
        $value.FontSize = [Math]::Max(10, [double]$script:Settings.FontSize - 1)
        $value.Foreground = Convert-Brush $script:Settings.TextColor 0.86
    }

    $fpsSecondary.FontSize = [double]$script:Settings.FontSize
    $fpsSecondary.FontWeight = "Bold"
    $fpsSecondary.Foreground = Convert-Brush $script:Settings.TextColor 1

    if ($script:WindowHandle -ne [IntPtr]::Zero) {
        [PulseHudNative]::SetClickThrough($script:WindowHandle, [bool]$script:Settings.ClickThrough, $showInTaskbar)
    }

    if (-not $script:DialogStarted) {
        return
    }

    if (-not $script:HiddenByHotkey) {
        $window.Show()
    }

    Update-StartupShortcut
}

# Watch config/settings.json and live-apply panel edits.
function Reload-SettingsIfNeeded {
    if (-not (Test-Path -LiteralPath $ConfigPath)) { return }
    $write = (Get-Item -LiteralPath $ConfigPath).LastWriteTimeUtc
    if ($write -eq $script:LastConfigWrite) { return }

    $script:LastConfigWrite = $write
    $script:Settings = Get-Settings
    Apply-SettingsToWindow
}

# Global hotkey and tray menu both use this same show/hide action.
function Toggle-Overlay {
    $script:HiddenByHotkey = -not $script:HiddenByHotkey
    if ($script:HiddenByHotkey) {
        $window.Hide()
    } else {
        $window.Show()
        $window.Activate()
    }
}

# Register the configured global hotkey with the hidden WPF window handle.
function Register-ToggleHotkey {
    if ($script:WindowHandle -eq [IntPtr]::Zero) { return }

    try {
        [PulseHudNative]::UnregisterHotKey($script:WindowHandle, $script:HotkeyId) | Out-Null
        $hotkey = Parse-Hotkey $script:Settings.ToggleHotkey
        [PulseHudNative]::RegisterHotKey($script:WindowHandle, $script:HotkeyId, [uint32]$hotkey.Modifiers, [uint32]$hotkey.Key) | Out-Null
    } catch {
        Write-OverlayLog "Hotkey registration failed: $($_.Exception.Message)"
    }
}

# The tray tooltip mirrors the live values even when the taskbar entry is shown.
function Update-TrayText {
    param([string]$Fps, [string]$Cpu, [string]$Gpu, [string]$Ram)

    if ($null -eq $script:NotifyIcon) { return }

    $text = "$($script:Settings.AppName)`nFPS $Fps | CPU $Cpu`nGPU $Gpu | RAM $Ram"
    if ($text.Length -gt 63) { $text = $text.Substring(0, 63) }
    $script:NotifyIcon.Text = $text
}

# The Windows taskbar normally shows the window title only in hover previews or
# when taskbar labels are enabled, so this mirrors live metrics there.
function Update-TaskbarTitle {
    param([string]$Fps, [string]$Cpu, [string]$Gpu, [string]$Ram)

    if ($script:Settings.Mode -eq "Taskbar" -or [bool]$script:Settings.ShowInTaskbar) {
        $window.Title = "FPS $Fps | CPU $Cpu | GPU $Gpu | RAM $Ram"
    } else {
        $window.Title = $script:Settings.AppName
    }
}

# Build the borderless overlay window. WindowStyle=None removes the title bar.
$window = New-Object System.Windows.Window
$window.WindowStyle = "None"
$window.ResizeMode = "NoResize"
$window.AllowsTransparency = $true
$window.Background = [System.Windows.Media.Brushes]::Transparent
$window.Topmost = $true
$window.ShowInTaskbar = $false
$window.SizeToContent = "Manual"

$border = New-Object System.Windows.Controls.Border
$border.CornerRadius = 6
$border.Padding = "10,8,10,8"
$border.BorderThickness = 1

$grid = New-Object System.Windows.Controls.Grid
$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "48" }))
$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "52" }))
$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))
1..4 | ForEach-Object {
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "25" }))
}

$fpsPrimary = New-TextBlock "--" $script:Settings.FontSize "Bold" $script:Settings.TextColor
$cpuPrimary = New-TextBlock "--" $script:Settings.FontSize "Bold" $script:Settings.TextColor
$gpuPrimary = New-TextBlock "--" $script:Settings.FontSize "Bold" $script:Settings.TextColor
$ramPrimary = New-TextBlock "--" $script:Settings.FontSize "Bold" $script:Settings.TextColor
$fpsSecondary = New-TextBlock "" $script:Settings.FontSize "SemiBold" $script:Settings.TextColor
$cpuSecondary = New-TextBlock "" $script:Settings.FontSize "SemiBold" $script:Settings.TextColor
$gpuSecondary = New-TextBlock "" $script:Settings.FontSize "SemiBold" $script:Settings.TextColor
$ramSecondary = New-TextBlock "" $script:Settings.FontSize "SemiBold" $script:Settings.TextColor

$script:LabelBlocks = @()
$script:LabelBlocks += Add-MetricRow $grid 0 "FPS" $fpsPrimary $fpsSecondary
$script:LabelBlocks += Add-MetricRow $grid 1 "CPU" $cpuPrimary $cpuSecondary
$script:LabelBlocks += Add-MetricRow $grid 2 "GPU" $gpuPrimary $gpuSecondary
$script:LabelBlocks += Add-MetricRow $grid 3 "RAM" $ramPrimary $ramSecondary

$border.Child = $grid
$window.Content = $border

$script:HiddenByHotkey = $false

# Dragging is enabled by default; click-through disables mouse interaction.
$window.Add_MouseLeftButtonDown({
    if (-not [bool]$script:Settings.ClickThrough) {
        try { $window.DragMove() } catch {}
    }
})

# Persist the user's dragged position automatically.
$window.Add_LocationChanged({
    if ($script:Settings -and $window.IsVisible) {
        $script:Settings.X = [int]$window.Left
        $script:Settings.Y = [int]$window.Top
        Save-Settings $script:Settings
        $script:LastConfigWrite = (Get-Item -LiteralPath $ConfigPath).LastWriteTimeUtc
    }
})

# Once WPF creates a real HWND, apply extended styles and register the hotkey.
$window.Add_SourceInitialized({
    $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
    $script:WindowHandle = $helper.Handle
    $showInTaskbar = [bool]$script:Settings.ShowInTaskbar -or $script:Settings.Mode -eq "Taskbar"
    [PulseHudNative]::SetClickThrough($script:WindowHandle, [bool]$script:Settings.ClickThrough, $showInTaskbar)
    Register-ToggleHotkey

    $source = [System.Windows.Interop.HwndSource]::FromHwnd($script:WindowHandle)
    $source.AddHook({
        param($hwnd, $msg, $wParam, $lParam, [ref]$handled)
        if ($msg -eq [PulseHudNative]::WM_HOTKEY -and $wParam.ToInt32() -eq $script:HotkeyId) {
            Toggle-Overlay
            $handled.Value = $true
        }
        return [IntPtr]::Zero
    })
})

# Hide only after ShowDialog has started; hiding before ShowDialog breaks WPF.
$window.Add_Loaded({
    $script:DialogStarted = $true
    if ($script:HiddenByHotkey) {
        $window.Hide()
    }
})

# Cleanup native registrations, tray icon, and pid file.
$window.Add_Closed({
    try {
        if ($script:WindowHandle -ne [IntPtr]::Zero) {
            [PulseHudNative]::UnregisterHotKey($script:WindowHandle, $script:HotkeyId) | Out-Null
        }
        if ($null -ne $script:NotifyIcon) {
            $script:NotifyIcon.Visible = $false
            $script:NotifyIcon.Dispose()
        }
    } catch {}
    Remove-Item -LiteralPath $script:PidPath -ErrorAction SilentlyContinue
    Write-OverlayLog "Overlay closed."
})

# Tray icon gives users a way to show/hide/configure/exit without a taskbar item.
if (-not $NoTray) {
    $script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $iconPath = Join-Path $script:ProjectRoot "assets\logo.ico"
    $script:NotifyIcon.Icon = if (Test-Path -LiteralPath $iconPath) { [System.Drawing.Icon]::new($iconPath) } else { [System.Drawing.SystemIcons]::Application }
    $script:NotifyIcon.Visible = $true

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $showItem = $menu.Items.Add("Mostrar/Ocultar")
    $configItem = $menu.Items.Add("Configurar")
    $exitItem = $menu.Items.Add("Sair")

    $showItem.Add_Click({ Toggle-Overlay })
    $configItem.Add_Click({
        $configExe = Join-Path $script:ProjectRoot "bin\PulseHUDConfig.exe"
        if (Test-Path -LiteralPath $configExe) {
            Start-Process -FilePath $configExe -WorkingDirectory $script:ProjectRoot
        } else {
            Start-Process powershell.exe -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-STA", "-File", "`"$script:ProjectRoot\src\ConfigurarOverlay.ps1`"") -WorkingDirectory $script:ProjectRoot
        }
    })
    $exitItem.Add_Click({ $window.Close() })
    $script:NotifyIcon.ContextMenuStrip = $menu
    $script:NotifyIcon.Add_DoubleClick({ Toggle-Overlay })
}

# Apply initial JSON settings before entering the WPF message loop.
Apply-SettingsToWindow

# Refresh metrics and live settings on a DispatcherTimer so UI updates are safe.
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds([Math]::Max(250, [int]$script:Settings.IntervalMs))
$timer.Add_Tick({
    Reload-SettingsIfNeeded

    $fps = Get-FpsText
    $cpu = Get-CpuText
    $gpu = Get-GpuText
    $ram = Get-RamText

    $cpuParts = Split-MetricText $cpu
    $gpuParts = Split-MetricText $gpu
    $ramParts = Split-MetricText $ram

    $fpsPrimary.Text = ""
    $fpsSecondary.Text = $fps
    $cpuPrimary.Text = $cpuParts.Primary
    $cpuSecondary.Text = $cpuParts.Secondary
    $gpuPrimary.Text = $gpuParts.Primary
    $gpuSecondary.Text = $gpuParts.Secondary
    $ramPrimary.Text = $ramParts.Primary
    $ramSecondary.Text = $ramParts.Secondary
    $timer.Interval = [TimeSpan]::FromMilliseconds([Math]::Max(250, [int]$script:Settings.IntervalMs))

    Update-TrayText $fps $cpu $gpu $ram
    Update-TaskbarTitle $fps $cpu $gpu $ram
})

$timer.Start()
[void]$window.ShowDialog()
