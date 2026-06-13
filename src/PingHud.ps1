$ErrorActionPreference = "Continue"
. "$PSScriptRoot\PulseHudProCommon.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

$config = (Get-ProProfiles).PingHud
$history = @{}

$window = New-Object System.Windows.Window
Set-ProWindowStyle $window "Ping HUD" 360 150 -Topmost -Overlay
$window.ResizeMode = "NoResize"
$window.Left = 30
$window.Top = 180

$panel = New-Object System.Windows.Controls.StackPanel
$header = New-ProText "PING HUD" 12 "Bold" $script:PulseHudTheme.Accent -Mono
$header.Margin = "0,0,0,6"
$text = New-ProText "" 13 "Normal" $script:PulseHudTheme.Text -Mono
[void]$panel.Children.Add($header)
[void]$panel.Children.Add($text)
$window.Content = New-ProPanel $panel "10" "0"
$window.Add_MouseLeftButtonDown({ try { $window.DragMove() } catch {} })

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds([Math]::Max(1, [int]$config.IntervalSeconds))
$timer.Add_Tick({
    $lines = @()
    foreach ($target in @($config.Hosts)) {
        $key = [string]$target.Host
        if (-not $history.ContainsKey($key)) { $history[$key] = New-Object System.Collections.ArrayList }
        $ms = $null
        try {
            $reply = Test-Connection -ComputerName $target.Host -Count 1 -ErrorAction Stop | Select-Object -First 1
            $ms = [double]$reply.ResponseTime
        } catch {}
        [void]$history[$key].Add($ms)
        while ($history[$key].Count -gt 20) { $history[$key].RemoveAt(0) }
        $vals = @($history[$key] | Where-Object { $null -ne $_ })
        $loss = if ($history[$key].Count -gt 0) { 100 - (($vals.Count / $history[$key].Count) * 100) } else { 100 }
        $avg = if ($vals.Count) { ($vals | Measure-Object -Average).Average } else { $null }
        $jitter = if ($vals.Count -gt 1) {
            $diffs = for ($i = 1; $i -lt $vals.Count; $i++) { [Math]::Abs($vals[$i] - $vals[$i - 1]) }
            ($diffs | Measure-Object -Average).Average
        } else { 0 }
        $ping = if ($null -ne $ms) { "{0:N0}ms" -f $ms } else { "--" }
        $avgText = if ($null -ne $avg) { "{0:N0}" -f $avg } else { "--" }
        $lines += "{0}: {1} avg {2} loss {3:N0}% jit {4:N0}" -f $target.Name, $ping, $avgText, $loss, $jitter
    }
    $text.Text = $lines -join "`n"
})
$timer.Start()
[void]$window.ShowDialog()
