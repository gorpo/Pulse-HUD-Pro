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
$window.Title = "Aim Warmup Timer"
$window.Width = 360
$window.Height = 240
$window.WindowStartupLocation = "CenterScreen"
$panel = New-Object System.Windows.Controls.StackPanel
$panel.Margin = "18"
$name = New-Object System.Windows.Controls.TextBlock
$name.FontSize = 24
$name.FontWeight = "Bold"
$time = New-Object System.Windows.Controls.TextBlock
$time.FontSize = 42
$time.FontFamily = "Consolas"
$button = New-Object System.Windows.Controls.Button
$button.Content = "Iniciar/Pausar"
$button.Height = 34
$button.Add_Click({ $script:running = -not $script:running })
$panel.Children.Add($name) | Out-Null
$panel.Children.Add($time) | Out-Null
$panel.Children.Add($button) | Out-Null
$window.Content = $panel

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
