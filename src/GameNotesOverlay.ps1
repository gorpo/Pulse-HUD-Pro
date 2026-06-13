$ErrorActionPreference = "Continue"
. "$PSScriptRoot\PulseHudProCommon.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

$notes = @((Get-ProProfiles).GameNotesOverlay.Notes)

$window = New-Object System.Windows.Window
$window.Title = "Game Notes Overlay"
$window.Width = 360
$window.Height = 240
$window.Topmost = $true
$window.WindowStyle = "None"
$window.ResizeMode = "CanResizeWithGrip"
$window.Background = "#111827"
$window.Opacity = 0.9
$window.Left = 40
$window.Top = 330
$text = New-Object System.Windows.Controls.TextBlock
$text.Margin = "12"
$text.FontFamily = "Segoe UI"
$text.FontSize = 14
$text.Foreground = "#F8FAFC"
$text.TextWrapping = "Wrap"
$window.Content = $text
$window.Add_MouseLeftButtonDown({ try { $window.DragMove() } catch {} })

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(2)
$timer.Add_Tick({
    $match = $null
    foreach ($note in $notes) {
        if (Get-Process -Name $note.ProcessName -ErrorAction SilentlyContinue) { $match = $note; break }
    }
    if ($null -eq $match -and $notes.Count -gt 0) { $match = $notes[0] }
    if ($match) { $text.Text = "$($match.Game)`n`n$($match.Text)" }
})
$timer.Start()
[void]$window.ShowDialog()
