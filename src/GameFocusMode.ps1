$ErrorActionPreference = "Continue"
. "$PSScriptRoot\PulseHudProCommon.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

$config = Get-ProProfiles
$focus = $config.GameFocusMode
$activeProfile = $null
$originalPower = ""

function Invoke-FocusEnter {
    param($Profile)

    $script:originalPower = Get-ProPowerSchemeGuid
    Stop-ProProcesses $Profile.CloseProcesses
    foreach ($app in @($Profile.StartApps)) { [void](Start-ProConfiguredApp $app) }
    if ($focus.PowerPlan) { Set-ProPowerPlan $focus.PowerPlan }
    Set-ProProcessPriority $Profile.ProcessName $Profile.Priority
    Write-ProLog "focus" "Ativado: $($Profile.Name)"
}

function Invoke-FocusExit {
    param($Profile)

    if ($focus.RestorePowerPlan -and $script:originalPower) {
        Set-ProPowerPlan $script:originalPower
    }
    Write-ProLog "focus" "Restaurado: $($Profile.Name)"
    $script:originalPower = ""
}

$window = New-Object System.Windows.Window
Set-ProWindowStyle $window "Game Focus Mode" 500 300

$panel = New-Object System.Windows.Controls.StackPanel
$panel.Margin = "16"
$title = New-ProText "GAME FOCUS MODE" 16 "Bold" $script:PulseHudTheme.Accent
$title.Margin = "0,0,0,10"
$text = New-ProText "" 14 "Normal" $script:PulseHudTheme.Text
$panel.Children.Add($title) | Out-Null
$panel.Children.Add($text) | Out-Null
$window.Content = New-ProPanel $panel "14" "0"

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds([Math]::Max(2, [int]$focus.PollSeconds))
$timer.Add_Tick({
    $running = $null
    foreach ($profile in @($focus.Profiles)) {
        if (Get-Process -Name $profile.ProcessName -ErrorAction SilentlyContinue) {
            $running = $profile
            break
        }
    }

    if ($null -ne $running -and ($null -eq $script:activeProfile -or $script:activeProfile.Name -ne $running.Name)) {
        if ($null -ne $script:activeProfile) { Invoke-FocusExit $script:activeProfile }
        $script:activeProfile = $running
        Invoke-FocusEnter $running
    } elseif ($null -eq $running -and $null -ne $script:activeProfile) {
        Invoke-FocusExit $script:activeProfile
        $script:activeProfile = $null
    }

    $status = if ($null -ne $script:activeProfile) { "ATIVO: $($script:activeProfile.Name)" } else { "Aguardando jogos configurados..." }
    $names = @($focus.Profiles | ForEach-Object { "$($_.Name) ($($_.ProcessName).exe)" }) -join "`n"
    $text.Text = "$status`n`nPerfis:`n$names`n`nUse Profile Editor para trocar jogos, apps e processos."
})
$timer.Start()
$window.Add_Closed({ if ($null -ne $script:activeProfile) { Invoke-FocusExit $script:activeProfile } })
[void]$window.ShowDialog()
