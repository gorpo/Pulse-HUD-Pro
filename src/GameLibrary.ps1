$ErrorActionPreference = "Continue"
. "$PSScriptRoot\GameLibraryBackend.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

$script:Catalog = @()

function Set-LibraryStatus {
    param([string]$Message, [string]$Color = $script:PulseHudTheme.Muted)
    $status.Foreground = $Color
    $status.Text = $Message
}

function Update-GameList {
    param([object[]]$Entries)

    $script:Catalog = @($Entries)
    $list.Items.Clear()
    foreach ($game in $script:Catalog) {
        $flag = if ($game.CanUninstall) { "uninstall" } elseif ($game.CanDeleteFiles) { "pasta" } else { "catalogo" }
        [void]$list.Items.Add("$($game.Name)  [$($game.Source) / $flag]")
    }
    if ($list.Items.Count -gt 0 -and $list.SelectedIndex -lt 0) { $list.SelectedIndex = 0 }
    Update-Details
}

function Get-SelectedGame {
    if ($list.SelectedIndex -lt 0 -or $list.SelectedIndex -ge $script:Catalog.Count) { return $null }
    return $script:Catalog[$list.SelectedIndex]
}

function Update-Details {
    $game = Get-SelectedGame
    if ($null -eq $game) {
        $details.Text = "Nenhum jogo selecionado."
        return
    }
    $details.Text = "Nome: $($game.Name)`nFonte: $($game.Source)`nPasta: $($game.InstallPath)`nExecutavel: $($game.LaunchPath)`nUninstall: $([bool]$game.CanUninstall)`nDelete pasta: $([bool]$game.CanDeleteFiles)"
}

function Load-Catalog {
    Update-GameList (Get-GameCatalog)
    Set-LibraryStatus "Catalogo carregado: $($script:Catalog.Count) jogo(s)."
}

function Scan-Games {
    Set-LibraryStatus "Varrendo jogos..."
    $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
    try {
        Update-GameList (Invoke-GameScan)
        Set-LibraryStatus "Varredura concluida: $($script:Catalog.Count) jogo(s)." $script:PulseHudTheme.Success
    } catch {
        Set-LibraryStatus "Falha na varredura: $($_.Exception.Message)" $script:PulseHudTheme.Danger
    }
}

function Open-SelectedGame {
    $game = Get-SelectedGame
    if ($null -eq $game) { return }
    try { Start-GameEntry $game } catch { Set-LibraryStatus $_.Exception.Message $script:PulseHudTheme.Danger }
}

function Open-SelectedFolder {
    $game = Get-SelectedGame
    if ($null -eq $game -or -not $game.InstallPath -or -not (Test-Path -LiteralPath $game.InstallPath)) { return }
    Start-Process explorer.exe -ArgumentList "`"$($game.InstallPath)`""
}

function Forget-SelectedGame {
    $game = Get-SelectedGame
    if ($null -eq $game) { return }
    $confirm = [System.Windows.MessageBox]::Show("Remover '$($game.Name)' apenas do catalogo do Pulse HUD Pro?", "Game Library", "YesNo", "Question")
    if ($confirm -ne "Yes") { return }
    Update-GameList (Remove-GameFromCatalog $game.Id)
    Set-LibraryStatus "Removido do catalogo: $($game.Name)." $script:PulseHudTheme.Success
}

function Uninstall-SelectedGame {
    $game = Get-SelectedGame
    if ($null -eq $game) { return }
    if (-not $game.CanUninstall) {
        Set-LibraryStatus "Este item nao tem desinstalador oficial detectado." $script:PulseHudTheme.Danger
        return
    }
    $confirm = [System.Windows.MessageBox]::Show("Abrir desinstalador oficial de '$($game.Name)'?", "Game Library", "YesNo", "Warning")
    if ($confirm -ne "Yes") { return }
    try {
        Start-GameUninstall $game
        Set-LibraryStatus "Desinstalador chamado para $($game.Name)." $script:PulseHudTheme.Success
    } catch {
        Set-LibraryStatus $_.Exception.Message $script:PulseHudTheme.Danger
    }
}

function Delete-SelectedGameFolder {
    $game = Get-SelectedGame
    if ($null -eq $game) { return }
    if (-not $game.CanDeleteFiles) {
        Set-LibraryStatus "Este item nao foi detectado em uma GameRoot segura." $script:PulseHudTheme.Danger
        return
    }
    $confirm = [System.Windows.MessageBox]::Show("Mover a pasta de '$($game.Name)' para a Lixeira?`n`n$($game.InstallPath)", "Game Library", "YesNo", "Warning")
    if ($confirm -ne "Yes") { return }
    try {
        Remove-GameFilesToRecycleBin $game
        Update-GameList (Remove-GameFromCatalog $game.Id)
        Set-LibraryStatus "Pasta enviada para a Lixeira: $($game.Name)." $script:PulseHudTheme.Success
    } catch {
        Set-LibraryStatus $_.Exception.Message $script:PulseHudTheme.Danger
    }
}

$window = New-Object System.Windows.Window
Set-ProWindowStyle $window "Pulse HUD Pro - Game Library" 900 620

$rootGrid = New-Object System.Windows.Controls.Grid
$rootGrid.Margin = "18"
$rootGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))
$rootGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "*" }))
$rootGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))
$rootGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "2*" }))
$rootGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "1.4*" }))

$title = New-ProText "Game Library" 28 "Bold" $script:PulseHudTheme.Text
$subtitle = New-ProText "Varredura local, catalogo, abertura, remocao segura e desinstalador oficial quando disponivel." 12 "Normal" $script:PulseHudTheme.Muted
$header = New-Object System.Windows.Controls.StackPanel
$header.Margin = "0,0,0,14"
$header.Children.Add($title) | Out-Null
$header.Children.Add($subtitle) | Out-Null
[System.Windows.Controls.Grid]::SetRow($header, 0)
[System.Windows.Controls.Grid]::SetColumnSpan($header, 2)
$rootGrid.Children.Add($header) | Out-Null

$list = New-Object System.Windows.Controls.ListBox
$list.Background = $script:PulseHudTheme.PanelAlt
$list.Foreground = $script:PulseHudTheme.Text
$list.BorderBrush = $script:PulseHudTheme.Accent
$list.Margin = "0,0,12,12"
[System.Windows.Controls.Grid]::SetRow($list, 1)
[System.Windows.Controls.Grid]::SetColumn($list, 0)
$rootGrid.Children.Add($list) | Out-Null

$sidePanel = New-Object System.Windows.Controls.StackPanel
$detailsTitle = New-ProText "Detalhes" 16 "Bold" $script:PulseHudTheme.Accent
$detailsTitle.Margin = "0,0,0,8"
$details = New-ProText "" 12 "Normal" $script:PulseHudTheme.Text -Mono
$details.Margin = "0,0,0,12"
$buttonPanel = New-Object System.Windows.Controls.WrapPanel
$scanButton = New-ProButton "Varrer jogos" 120 34 "Primary"
$openButton = New-ProButton "Abrir" 86 34
$folderButton = New-ProButton "Pasta" 86 34
$forgetButton = New-ProButton "Remover catalogo" 146 34
$uninstallButton = New-ProButton "Desinstalar" 110 34 "Danger"
$deleteButton = New-ProButton "Lixeira" 92 34 "Danger"
$scanButton.Add_Click({ Scan-Games })
$openButton.Add_Click({ Open-SelectedGame })
$folderButton.Add_Click({ Open-SelectedFolder })
$forgetButton.Add_Click({ Forget-SelectedGame })
$uninstallButton.Add_Click({ Uninstall-SelectedGame })
$deleteButton.Add_Click({ Delete-SelectedGameFolder })
foreach ($button in @($scanButton, $openButton, $folderButton, $forgetButton, $uninstallButton, $deleteButton)) {
    $buttonPanel.Children.Add($button) | Out-Null
}
$sidePanel.Children.Add($detailsTitle) | Out-Null
$sidePanel.Children.Add($details) | Out-Null
$sidePanel.Children.Add($buttonPanel) | Out-Null
[System.Windows.Controls.Grid]::SetRow($sidePanel, 1)
[System.Windows.Controls.Grid]::SetColumn($sidePanel, 1)
$rootGrid.Children.Add((New-ProPanel $sidePanel "14" "0,0,0,12")) | Out-Null

$status = New-ProText "" 12 "Normal" $script:PulseHudTheme.Muted
[System.Windows.Controls.Grid]::SetRow($status, 2)
[System.Windows.Controls.Grid]::SetColumnSpan($status, 2)
$rootGrid.Children.Add($status) | Out-Null

$list.Add_SelectionChanged({ Update-Details })
$window.Content = $rootGrid
$window.Add_Loaded({ Load-Catalog })
[void]$window.ShowDialog()
