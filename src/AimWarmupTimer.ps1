$ErrorActionPreference = "Continue"
. "$PSScriptRoot\PulseHudProCommon.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

$blocks = @((Get-ProProfiles).AimWarmupTimer.Blocks)
$index = 0
$remaining = [int]$blocks[0].Seconds
$running = $false

$window = New-Object System.Windows.Window
Set-ProWindowStyle $window "Aim Warmup Timer" 380 260
$panel = New-Object System.Windows.Controls.StackPanel
$panel.Margin = "18"
$title = New-ProText "AIM WARMUP" 16 "Bold" $script:PulseHudTheme.Accent
$title.Margin = "0,0,0,10"
$name = New-ProText "" 24 "Bold" $script:PulseHudTheme.Text
$time = New-ProText "" 42 "Bold" $script:PulseHudTheme.Accent -Mono
$button = New-ProButton "Iniciar/Pausar" 130 34 "Primary"
$button.Add_Click({ $script:running = -not $script:running })
$panel.Children.Add($title) | Out-Null
$panel.Children.Add($name) | Out-Null
$panel.Children.Add($time) | Out-Null
$panel.Children.Add($button) | Out-Null
$window.Content = New-ProPanel $panel "14" "0"

function Update-View {
    $name.Text = $blocks[$script:index].Name
    $time.Text = "{0:mm\:ss}" -f ([TimeSpan]::FromSeconds($script:remaining))
}

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    if ($script:running) {
        $script:remaining--
        if ($script:remaining -le 0) {
            [System.Media.SystemSounds]::Asterisk.Play()
            $script:index = ($script:index + 1) % $blocks.Count
            $script:remaining = [int]$blocks[$script:index].Seconds
        }
    }
    Update-View
})
Update-View
$timer.Start()
[void]$window.ShowDialog()
