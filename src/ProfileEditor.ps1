$ErrorActionPreference = "Stop"
. "$PSScriptRoot\PulseHudProCommon.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

$script:Profiles = Get-ProProfiles
$script:CurrentModule = ""

function Save-ProfilesFile {
    param($Profiles)

    $backupDir = Join-Path $script:PulseHudProRuntime "backups"
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    if (Test-Path -LiteralPath $script:PulseHudProProfilesPath) {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        Copy-Item -LiteralPath $script:PulseHudProProfilesPath -Destination (Join-Path $backupDir "profiles-$stamp.json") -Force
    }
    $Profiles | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $script:PulseHudProProfilesPath -Encoding UTF8
}

function Set-Status {
    param([string]$Message, [string]$Color = $script:PulseHudTheme.Muted)
    $status.Foreground = $Color
    $status.Text = $Message
}

function Load-ModuleText {
    if ($moduleList.SelectedItem -eq $null) { return }
    $script:CurrentModule = [string]$moduleList.SelectedItem
    $moduleValue = $script:Profiles.$($script:CurrentModule)
    $editor.Text = $moduleValue | ConvertTo-Json -Depth 20
    Set-Status "Editando $script:CurrentModule. O arquivo sera validado antes de salvar."
}

function Save-CurrentModule {
    if ([string]::IsNullOrWhiteSpace($script:CurrentModule)) { return }

    try {
        $parsed = $editor.Text | ConvertFrom-Json -ErrorAction Stop
        $script:Profiles.$($script:CurrentModule) = $parsed
        Save-ProfilesFile $script:Profiles
        Set-Status "Salvo com backup em .runtime\\backups." $script:PulseHudTheme.Success
    } catch {
        Set-Status "JSON invalido: $($_.Exception.Message)" $script:PulseHudTheme.Danger
    }
}

function Reload-Profiles {
    try {
        $script:Profiles = Get-ProProfiles
        $selected = $script:CurrentModule
        $moduleList.Items.Clear()
        foreach ($name in $script:Profiles.PSObject.Properties.Name) {
            [void]$moduleList.Items.Add($name)
        }
        if ($selected -and $moduleList.Items.Contains($selected)) {
            $moduleList.SelectedItem = $selected
        } elseif ($moduleList.Items.Count -gt 0) {
            $moduleList.SelectedIndex = 0
        }
        Set-Status "Profiles recarregado."
    } catch {
        Set-Status "Falha ao recarregar: $($_.Exception.Message)" $script:PulseHudTheme.Danger
    }
}

$window = New-Object System.Windows.Window
Set-ProWindowStyle $window "Pulse HUD Pro - Profile Editor" 840 620

$rootPanel = New-Object System.Windows.Controls.Grid
$rootPanel.Margin = "18"
$rootPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "230" }))
$rootPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))
$rootPanel.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))
$rootPanel.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "*" }))
$rootPanel.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))

$title = New-ProText "Profile Editor" 26 "Bold" $script:PulseHudTheme.Text
$title.Margin = "0,0,0,14"
[System.Windows.Controls.Grid]::SetColumnSpan($title, 2)
[System.Windows.Controls.Grid]::SetRow($title, 0)
[void]$rootPanel.Children.Add($title)

$moduleList = New-Object System.Windows.Controls.ListBox
$moduleList.Background = $script:PulseHudTheme.PanelAlt
$moduleList.Foreground = $script:PulseHudTheme.Text
$moduleList.BorderBrush = $script:PulseHudTheme.Border
$moduleList.Margin = "0,0,12,12"
[System.Windows.Controls.Grid]::SetRow($moduleList, 1)
[System.Windows.Controls.Grid]::SetColumn($moduleList, 0)
[void]$rootPanel.Children.Add($moduleList)

$editor = New-Object System.Windows.Controls.TextBox
$editor.AcceptsReturn = $true
$editor.AcceptsTab = $true
$editor.VerticalScrollBarVisibility = "Auto"
$editor.HorizontalScrollBarVisibility = "Auto"
$editor.FontFamily = "Consolas"
$editor.FontSize = 13
$editor.Background = "#05080D"
$editor.Foreground = $script:PulseHudTheme.Text
$editor.BorderBrush = $script:PulseHudTheme.Accent
$editor.TextWrapping = "NoWrap"
$editor.Margin = "0,0,0,12"
[System.Windows.Controls.Grid]::SetRow($editor, 1)
[System.Windows.Controls.Grid]::SetColumn($editor, 1)
[void]$rootPanel.Children.Add($editor)

$footer = New-Object System.Windows.Controls.Grid
$footer.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))
$footer.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "Auto" }))
[System.Windows.Controls.Grid]::SetRow($footer, 2)
[System.Windows.Controls.Grid]::SetColumnSpan($footer, 2)
[void]$rootPanel.Children.Add($footer)

$status = New-ProText "" 12 "Normal" $script:PulseHudTheme.Muted
$status.VerticalAlignment = "Center"
[System.Windows.Controls.Grid]::SetColumn($status, 0)
[void]$footer.Children.Add($status)

$buttons = New-Object System.Windows.Controls.WrapPanel
$buttons.HorizontalAlignment = "Right"
$save = New-ProButton "Salvar modulo" 128 34 "Primary"
$reload = New-ProButton "Recarregar" 104 34
$openRaw = New-ProButton "Abrir JSON" 104 34
$save.Add_Click({ Save-CurrentModule })
$reload.Add_Click({ Reload-Profiles })
$openRaw.Add_Click({ Start-Process notepad.exe -ArgumentList "`"$script:PulseHudProProfilesPath`"" })
[void]$buttons.Children.Add($save)
[void]$buttons.Children.Add($reload)
[void]$buttons.Children.Add($openRaw)
[System.Windows.Controls.Grid]::SetColumn($buttons, 1)
[void]$footer.Children.Add($buttons)

$moduleList.Add_SelectionChanged({ Load-ModuleText })

$window.Content = $rootPanel
$window.Add_Loaded({ Reload-Profiles })
[void]$window.ShowDialog()
