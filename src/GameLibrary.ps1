$ErrorActionPreference = "Continue"
. "$PSScriptRoot\GameLibraryBackend.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

$script:Catalog = @()

function Get-GameDisplayPath {
    param($Game)
    if ($Game.InstallPath) { return $Game.InstallPath }
    if ($Game.LaunchPath) { return $Game.LaunchPath }
    return "Sem caminho local detectado"
}

function New-GameListItem {
    param($Game)

    $item = New-Object System.Windows.Controls.ListBoxItem
    $item.Tag = $Game.Id
    $item.Padding = "6"
    $item.Margin = "0,0,0,4"
    $item.Background = $script:PulseHudTheme.PanelAlt
    $item.Foreground = $script:PulseHudTheme.Text

    $row = New-Object System.Windows.Controls.Grid
    $row.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "48" }))
    $row.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))
    $row.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "Auto" }))

    if ($Game.IconPath -and (Test-Path -LiteralPath $Game.IconPath)) {
        $image = New-Object System.Windows.Controls.Image
        $image.Width = 38
        $image.Height = 38
        $image.Margin = "0,0,8,0"
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.UriSource = [Uri]$Game.IconPath
        $bitmap.EndInit()
        $image.Source = $bitmap
        [System.Windows.Controls.Grid]::SetColumn($image, 0)
        $row.Children.Add($image) | Out-Null
    } else {
        $badge = New-ProText "GG" 13 "Bold" $script:PulseHudTheme.Accent -Mono
        $badge.HorizontalAlignment = "Center"
        $badge.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($badge, 0)
        $row.Children.Add($badge) | Out-Null
    }

    $texts = New-Object System.Windows.Controls.StackPanel
    $name = New-ProText $Game.Name 14 "SemiBold" $script:PulseHudTheme.Text
    $path = New-ProText (Get-GameDisplayPath $Game) 10 "Normal" $script:PulseHudTheme.Muted
    $path.TextTrimming = "CharacterEllipsis"
    $texts.Children.Add($name) | Out-Null
    $texts.Children.Add($path) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($texts, 1)
    $row.Children.Add($texts) | Out-Null

    $tags = New-Object System.Windows.Controls.StackPanel
    $tags.HorizontalAlignment = "Right"
    $source = New-ProText $Game.Source 10 "Bold" $script:PulseHudTheme.Accent
    $actions = @()
    if ($Game.LaunchPath) { $actions += "play" }
    if ($Game.CanUninstall) { $actions += "uninstall" }
    if ($Game.CanDeleteFiles) { $actions += "lixeira" }
    if ($actions.Count -eq 0) { $actions += "catalogo" }
    $actionText = New-ProText ($actions -join " / ") 10 "Normal" $script:PulseHudTheme.Muted
    $tags.Children.Add($source) | Out-Null
    $tags.Children.Add($actionText) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($tags, 2)
    $row.Children.Add($tags) | Out-Null

    $item.Content = $row
    return $item
}

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
        [void]$list.Items.Add((New-GameListItem $game))
    }
    if ($list.Items.Count -gt 0 -and $list.SelectedIndex -lt 0) { $list.SelectedIndex = 0 }
    Update-Details
}

function Get-SelectedGame {
    if ($null -eq $list.SelectedItem) { return $null }
    $id = [string]$list.SelectedItem.Tag
    return @($script:Catalog | Where-Object { $_.Id -eq $id } | Select-Object -First 1)[0]
}

function Update-Details {
    $game = Get-SelectedGame
    if ($null -eq $game) {
        $heroName.Text = "Selecione um jogo"
        $heroSource.Text = ""
        $heroIcon.Source = $null
        $details.Text = "Nenhum jogo selecionado."
        Update-ActionButtons $null
        return
    }

    $heroName.Text = $game.Name
    $heroSource.Text = "$($game.Source)  |  $(if ($game.CanUninstall) { 'desinstalador oficial' } elseif ($game.CanDeleteFiles) { 'pasta gerenciavel' } else { 'catalogo' })"
    if ($game.IconPath -and (Test-Path -LiteralPath $game.IconPath)) {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.UriSource = [Uri]$game.IconPath
        $bitmap.EndInit()
        $heroIcon.Source = $bitmap
    } else {
        $heroIcon.Source = $null
    }

    $details.Text = "Nome: $($game.Name)`nFonte: $($game.Source)`nPasta: $($game.InstallPath)`nExecutavel: $($game.LaunchPath)`nDesinstalador oficial: $([bool]$game.CanUninstall)`nRemocao para Lixeira: $([bool]$game.CanDeleteFiles)"
    Update-ActionButtons $game
}

function Update-ActionButtons {
    param($Game)

    $hasGame = $null -ne $Game
    $openButton.IsEnabled = $hasGame -and (($Game.LaunchPath -and (Test-Path -LiteralPath $Game.LaunchPath)) -or ($Game.InstallPath -and (Test-Path -LiteralPath $Game.InstallPath)))
    $folderButton.IsEnabled = $hasGame -and $Game.InstallPath -and (Test-Path -LiteralPath $Game.InstallPath)
    $forgetButton.IsEnabled = $hasGame
    $uninstallButton.IsEnabled = $hasGame -and [bool]$Game.CanUninstall
    $deleteButton.IsEnabled = $hasGame -and [bool]$Game.CanDeleteFiles

    $openButton.ToolTip = "Inicia o executavel detectado ou abre a pasta quando nao ha EXE."
    $folderButton.ToolTip = "Abre a pasta de instalacao detectada."
    $forgetButton.ToolTip = "Remove somente do catalogo do Pulse HUD Pro."
    $uninstallButton.ToolTip = "Abre o desinstalador oficial registrado no Windows, quando existe."
    $deleteButton.ToolTip = "Move para a Lixeira apenas pastas dentro das GameRoots configuradas."
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
    if ($null -eq $game) { Set-LibraryStatus "Selecione um jogo primeiro." $script:PulseHudTheme.Danger; return }
    try { Start-GameEntry $game } catch { Set-LibraryStatus $_.Exception.Message $script:PulseHudTheme.Danger }
}

function Open-SelectedFolder {
    $game = Get-SelectedGame
    if ($null -eq $game -or -not $game.InstallPath -or -not (Test-Path -LiteralPath $game.InstallPath)) {
        Set-LibraryStatus "Este item nao tem pasta local detectada." $script:PulseHudTheme.Danger
        return
    }
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
$hero = New-Object System.Windows.Controls.Grid
$hero.Margin = "0,0,0,14"
$hero.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "92" }))
$hero.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))
$heroIcon = New-Object System.Windows.Controls.Image
$heroIcon.Width = 78
$heroIcon.Height = 78
$heroIcon.Margin = "0,0,12,0"
$heroIcon.HorizontalAlignment = "Left"
$heroIcon.VerticalAlignment = "Top"
[System.Windows.Controls.Grid]::SetColumn($heroIcon, 0)
$hero.Children.Add($heroIcon) | Out-Null
$heroText = New-Object System.Windows.Controls.StackPanel
$heroName = New-ProText "Selecione um jogo" 20 "Bold" $script:PulseHudTheme.Text
$heroSource = New-ProText "" 11 "Normal" $script:PulseHudTheme.Accent
$heroText.Children.Add($heroName) | Out-Null
$heroText.Children.Add($heroSource) | Out-Null
[System.Windows.Controls.Grid]::SetColumn($heroText, 1)
$hero.Children.Add($heroText) | Out-Null
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
$sidePanel.Children.Add($hero) | Out-Null
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
