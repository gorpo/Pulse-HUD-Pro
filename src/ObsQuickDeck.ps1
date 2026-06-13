$ErrorActionPreference = "Continue"
. "$PSScriptRoot\PulseHudProCommon.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

$config = (Get-ProProfiles).ObsQuickDeck
$shell = New-Object -ComObject WScript.Shell

$window = New-Object System.Windows.Window
$window.Title = "OBS Quick Deck"
$window.Width = 320
$window.Height = 260
$window.Topmost = $true
$window.WindowStartupLocation = "CenterScreen"
$panel = New-Object System.Windows.Controls.WrapPanel
$panel.Margin = "12"

foreach ($action in @($config.Actions)) {
    $button = New-Object System.Windows.Controls.Button
    $button.Content = $action.Name
    $button.Width = 136
    $button.Height = 48
    $button.Margin = "0,0,8,8"
    $button.Tag = [string]$action.SendKeys
    $button.Add_Click({
        try {
            [void]$shell.AppActivate([string]$config.ObsWindowTitle)
            Start-Sleep -Milliseconds 120
            $shell.SendKeys([string]$this.Tag)
        } catch {}
    })
    $panel.Children.Add($button) | Out-Null
}

$window.Content = $panel
[void]$window.ShowDialog()
