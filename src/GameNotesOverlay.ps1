$ErrorActionPreference = "Continue"
. "$PSScriptRoot\PulseHudProCommon.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

$notes = @((Get-ProProfiles).GameNotesOverlay.Notes)

$window = New-Object System.Windows.Window
Set-ProWindowStyle $window "Game Notes Overlay" 380 250 -Topmost -Overlay
$window.Left = 40
$window.Top = 330

$panel = New-Object System.Windows.Controls.StackPanel
$header = New-ProText "GAME NOTES" 12 "Bold" $script:PulseHudTheme.Accent
$header.Margin = "0,0,0,8"
$text = New-ProText "" 14 "Normal" $script:PulseHudTheme.Text
[void]$panel.Children.Add($header)
[void]$panel.Children.Add($text)
$window.Content = New-ProPanel $panel "12" "0"
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
