$ErrorActionPreference = "Continue"
. "$PSScriptRoot\PulseHudProCommon.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

$config = (Get-ProProfiles).ThermalAlert
$aboveSince = $null
$cpu = $null
$gpuCounters = @()
try { $cpu = New-Object System.Diagnostics.PerformanceCounter("Processor", "% Processor Time", "_Total"); [void]$cpu.NextValue() } catch {}
try {
    $cat = New-Object System.Diagnostics.PerformanceCounterCategory("GPU Engine")
    foreach ($instance in ($cat.GetInstanceNames() | Where-Object { $_ -like "*engtype_3D*" })) {
        $c = New-Object System.Diagnostics.PerformanceCounter("GPU Engine", "Utilization Percentage", $instance)
        [void]$c.NextValue()
        $gpuCounters += $c
    }
} catch {}

function Get-ThermalZoneC {
    try {
        $raw = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop | Select-Object -First 1
        if ($raw.CurrentTemperature) { return ([double]$raw.CurrentTemperature / 10) - 273.15 }
    } catch {}
    return $null
}

$window = New-Object System.Windows.Window
$window.Title = "Thermal Alert"
$window.Width = 420
$window.Height = 240
$window.WindowStartupLocation = "CenterScreen"
$text = New-Object System.Windows.Controls.TextBlock
$text.Margin = "14"
$text.FontFamily = "Consolas"
$text.FontSize = 13
$text.TextWrapping = "Wrap"
$window.Content = $text

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds([Math]::Max(1, [int]$config.IntervalSeconds))
$timer.Add_Tick({
    $cpuPct = if ($cpu) { [double]$cpu.NextValue() } else { 0 }
    $gpuPct = 0.0
    foreach ($counter in $gpuCounters) { try { $gpuPct += $counter.NextValue() } catch {} }
    $temp = Get-ThermalZoneC
    $hot = ($cpuPct -ge [double]$config.CpuPercent) -or ($gpuPct -ge [double]$config.GpuPercent) -or ($temp -and $temp -ge [double]$config.ThermalZoneCelsius)
    if ($hot -and $null -eq $script:aboveSince) { $script:aboveSince = Get-Date }
    if (-not $hot) { $script:aboveSince = $null }
    $alert = ""
    if ($script:aboveSince -and ((Get-Date) - $script:aboveSince).TotalSeconds -ge [int]$config.SecondsAboveLimit) {
        $alert = "`nALERTA: limite alto por mais de $($config.SecondsAboveLimit)s"
        [System.Media.SystemSounds]::Exclamation.Play()
        Write-ProLog "thermal" "CPU=$cpuPct GPU=$gpuPct TEMP=$temp"
    }
    $tempText = if ($temp) { "{0:N1} C" -f $temp } else { "sensor indisponivel" }
    $text.Text = "CPU {0:N0}% / limite {1}%`nGPU {2:N0}% / limite {3}%`nTemp ACPI: {4}`n{5}" -f $cpuPct, $config.CpuPercent, $gpuPct, $config.GpuPercent, $tempText, $alert
})
$timer.Start()
[void]$window.ShowDialog()
