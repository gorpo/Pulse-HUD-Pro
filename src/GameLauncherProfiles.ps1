$ErrorActionPreference = "Continue"
. "$PSScriptRoot\PulseHudProCommon.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

$profiles = @((Get-ProProfiles).GameLauncherProfiles.Profiles)

function Start-GameProfile {
    param($Profile)
    Stop-ProProcesses $Profile.CloseProcesses
    foreach ($app in @($Profile.StartApps)) { [void](Start-ProConfiguredApp $app) }
    $game = Resolve-ProPath $Profile.GamePath
    if ([string]::IsNullOrWhiteSpace($game) -or -not (Test-Path -LiteralPath $game)) {
        [System.Windows.MessageBox]::Show("Configure GamePath em config\profiles.json.", "Pulse HUD Pro") | Out-Null
        return
    }
    $work = if ($Profile.WorkingDirectory) { Resolve-ProPath $Profile.WorkingDirectory } else { Split-Path -Parent $game }
    Start-Process -FilePath $game -ArgumentList $Profile.Arguments -WorkingDirectory $work
    Start-Sleep -Seconds 2
    Set-ProProcessPriority ([IO.Path]::GetFileNameWithoutExtension($game)) $Profile.Priority
}

$window = New-Object System.Windows.Window
$window.Title = "Game Launcher Profiles"
$window.Width = 460
$window.Height = 340
$window.WindowStartupLocation = "CenterScreen"
$panel = New-Object System.Windows.Controls.StackPanel
$panel.Margin = "14"
$list = New-Object System.Windows.Controls.ListBox
$list.Height = 220
foreach ($profile in $profiles) { [void]$list.Items.Add($profile.Name) }
$button = New-Object System.Windows.Controls.Button
$button.Content = "Abrir perfil"
$button.Height = 34
$button.Margin = "0,10,0,0"
$button.Add_Click({
    if ($list.SelectedIndex -ge 0) { Start-GameProfile $profiles[$list.SelectedIndex] }
})
$panel.Children.Add($list) | Out-Null
$panel.Children.Add($button) | Out-Null
$window.Content = $panel
[void]$window.ShowDialog()
