$ErrorActionPreference = "Continue"
. "$PSScriptRoot\PulseHudProCommon.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

$config = (Get-ProProfiles).ObsQuickDeck
$shell = New-Object -ComObject WScript.Shell

$window = New-Object System.Windows.Window
Set-ProWindowStyle $window "OBS Quick Deck" 350 300 -Topmost
$rootPanel = New-Object System.Windows.Controls.StackPanel
$rootPanel.Margin = "14"
$title = New-ProText "OBS QUICK DECK" 16 "Bold" $script:PulseHudTheme.Accent
$title.Margin = "0,0,0,10"
$panel = New-Object System.Windows.Controls.WrapPanel
$rootPanel.Children.Add($title) | Out-Null
$rootPanel.Children.Add($panel) | Out-Null

foreach ($action in @($config.Actions)) {
    $button = New-ProButton $action.Name 142 48
    $button.Margin = "0,0,8,8"
    $button.Tag = [string]$action.SendKeys
    $button.Add_Click({
        param($sender, $eventArgs)
        try {
            [void]$shell.AppActivate([string]$config.ObsWindowTitle)
            Start-Sleep -Milliseconds 120
            $shell.SendKeys([string]$sender.Tag)
        } catch {}
    })
    $panel.Children.Add($button) | Out-Null
}

$window.Content = New-ProPanel $rootPanel "14" "0"
[void]$window.ShowDialog()
