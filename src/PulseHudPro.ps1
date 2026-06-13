$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

function Start-ProScript {
    param(
        [string]$RelativePath,
        [switch]$Sta
    )

    $scriptPath = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        [System.Windows.MessageBox]::Show("Script nao encontrado:`n$scriptPath", "Pulse HUD Pro") | Out-Null
        return
    }

    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass")
    if ($Sta) { $args += "-STA" }
    $args += @("-File", "`"$scriptPath`"")
    Start-Process powershell.exe -ArgumentList $args -WorkingDirectory $root
}

function New-Text {
    param([string]$Text, [double]$Size, [string]$Weight = "Normal", [string]$Color = "#E8EEF6")

    $block = New-Object System.Windows.Controls.TextBlock
    $block.Text = $Text
    $block.FontFamily = "Segoe UI"
    $block.FontSize = $Size
    $block.FontWeight = $Weight
    $block.Foreground = $Color
    $block.TextWrapping = "Wrap"
    return $block
}

function Add-ToolButton {
    param(
        [System.Windows.Controls.Panel]$Parent,
        [string]$Title,
        [string]$Detail,
        [string]$Script,
        [switch]$Sta
    )

    $button = New-Object System.Windows.Controls.Button
    $button.Margin = "0,0,10,10"
    $button.Padding = "12"
    $button.MinHeight = 74
    $button.Background = "#17202A"
    $button.Foreground = "#E8EEF6"
    $button.BorderBrush = "#334155"
    $button.HorizontalContentAlignment = "Stretch"

    $stack = New-Object System.Windows.Controls.StackPanel
    $titleBlock = New-Text $Title 14 "SemiBold" "#FFFFFF"
    $detailBlock = New-Text $Detail 11 "Normal" "#AAB6C6"
    $detailBlock.Margin = "0,4,0,0"
    [void]$stack.Children.Add($titleBlock)
    [void]$stack.Children.Add($detailBlock)
    $button.Content = $stack
    $button.Add_Click({ Start-ProScript $Script -Sta:$Sta })
    [void]$Parent.Children.Add($button)
}

$window = New-Object System.Windows.Window
$window.Title = "Pulse HUD Pro"
$window.Width = 760
$window.Height = 620
$window.MinWidth = 620
$window.MinHeight = 500
$window.WindowStartupLocation = "CenterScreen"
$window.Background = "#0B1016"

$scroll = New-Object System.Windows.Controls.ScrollViewer
$scroll.VerticalScrollBarVisibility = "Auto"
$rootPanel = New-Object System.Windows.Controls.StackPanel
$rootPanel.Margin = "18"
$scroll.Content = $rootPanel

$title = New-Text "Pulse HUD Pro" 28 "Bold" "#FFFFFF"
$subtitle = New-Text "Suite leve para HUD, foco, rede, clips, OBS, notas e aquecimento." 13 "Normal" "#AAB6C6"
$subtitle.Margin = "0,2,0,18"
[void]$rootPanel.Children.Add($title)
[void]$rootPanel.Children.Add($subtitle)

$quickRow = New-Object System.Windows.Controls.WrapPanel
[void]$rootPanel.Children.Add($quickRow)

Add-ToolButton $quickRow "Pulse HUD" "Overlay de FPS, CPU, GPU e RAM." "src\OverlayLeve.ps1" -Sta
Add-ToolButton $quickRow "Configurar HUD" "Visual, hotkey, transparencia e modo taskbar." "src\ConfigurarOverlay.ps1" -Sta
Add-ToolButton $quickRow "Game Focus Mode" "Detecta jogos, muda energia, fecha apps e aplica prioridade." "src\GameFocusMode.ps1" -Sta
Add-ToolButton $quickRow "Game Launcher Profiles" "Abre jogos com apps, prioridade e limpeza de processos." "src\GameLauncherProfiles.ps1" -Sta
Add-ToolButton $quickRow "Clip Marker" "Hotkey para salvar timestamps de highlights." "src\ClipMarker.ps1" -Sta
Add-ToolButton $quickRow "Ping HUD" "Overlay de ping, perda e jitter." "src\PingHud.ps1" -Sta
Add-ToolButton $quickRow "Aim Warmup Timer" "Blocos de treino antes da partida." "src\AimWarmupTimer.ps1" -Sta
Add-ToolButton $quickRow "OBS Quick Deck" "Botoes visuais que disparam hotkeys no OBS." "src\ObsQuickDeck.ps1" -Sta
Add-ToolButton $quickRow "Thermal Alert" "Alertas de uso alto e temperatura quando o Windows expuser sensor." "src\ThermalAlert.ps1" -Sta
Add-ToolButton $quickRow "Game Notes Overlay" "Notas por jogo em overlay discreto." "src\GameNotesOverlay.ps1" -Sta
Add-ToolButton $quickRow "Brightness Control" "Controle gamer de brilho por DDC/CI e WMI." "src\BrightnessController.ps1" -Sta

$configButton = New-Object System.Windows.Controls.Button
$configButton.Content = "Abrir config\\profiles.json"
$configButton.Height = 34
$configButton.Width = 180
$configButton.Margin = "0,8,0,0"
$configButton.HorizontalAlignment = "Left"
$configButton.Add_Click({ Start-Process notepad.exe -ArgumentList "`"$(Join-Path $root 'config\profiles.json')`"" })
[void]$rootPanel.Children.Add($configButton)

$window.Content = $scroll
[void]$window.ShowDialog()
