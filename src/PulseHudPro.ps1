$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
. "$PSScriptRoot\PulseHudProCommon.ps1"

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

    Write-ProLog "dashboard" "Opening $RelativePath"
    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass")
    if ($Sta) { $args += "-STA" }
    $args += @("-File", "`"$scriptPath`"")
    Start-Process powershell.exe -ArgumentList $args -WorkingDirectory $root
}

function Add-ToolButton {
    param(
        [System.Windows.Controls.Panel]$Parent,
        [string]$Title,
        [string]$Detail,
        [string]$Script,
        [switch]$Sta
    )

    $button = New-ProButton "" 218 86
    $button.Margin = "0,0,10,10"
    $button.Padding = "12,10,12,10"
    $button.HorizontalContentAlignment = "Stretch"
    $button.Tag = [pscustomobject]@{
        Script = $Script
        Sta = [bool]$Sta
    }

    $stack = New-Object System.Windows.Controls.StackPanel
    $titleBlock = New-ProText $Title 14 "SemiBold" $script:PulseHudTheme.Text
    $detailBlock = New-ProText $Detail 11 "Normal" $script:PulseHudTheme.Muted
    $detailBlock.Margin = "0,4,0,0"
    [void]$stack.Children.Add($titleBlock)
    [void]$stack.Children.Add($detailBlock)
    $button.Content = $stack
    $button.Add_Click({
        param($sender, $eventArgs)
        $target = $sender.Tag
        Start-ProScript $target.Script -Sta:([bool]$target.Sta)
    })
    [void]$Parent.Children.Add($button)
}

$window = New-Object System.Windows.Window
Set-ProWindowStyle $window "Pulse HUD Pro" 820 660

$scroll = New-Object System.Windows.Controls.ScrollViewer
$scroll.VerticalScrollBarVisibility = "Auto"
$rootPanel = New-Object System.Windows.Controls.StackPanel
$rootPanel.Margin = "18"
$scroll.Content = $rootPanel

$title = New-ProText "Pulse HUD Pro" 30 "Bold" $script:PulseHudTheme.Text
$subtitle = New-ProText "Suite gamer leve para HUD, foco, rede, clips, OBS, notas, brilho e aquecimento." 13 "Normal" $script:PulseHudTheme.Muted
$subtitle.Margin = "0,2,0,18"
[void]$rootPanel.Children.Add($title)
[void]$rootPanel.Children.Add($subtitle)

$statusGrid = New-Object System.Windows.Controls.Grid
$statusGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))
$statusGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))
$statusGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))
foreach ($item in @(
    @("HUD", "Metricas em tempo real", $script:PulseHudTheme.Accent),
    @("FOCUS", "Perfis por jogo", $script:PulseHudTheme.Accent2),
    @("TOOLS", "Rede, brilho, clips e OBS", $script:PulseHudTheme.Success)
)) {
    $stack = New-Object System.Windows.Controls.StackPanel
    [void]$stack.Children.Add((New-ProText $item[0] 12 "Bold" $item[2]))
    [void]$stack.Children.Add((New-ProText $item[1] 12 "Normal" $script:PulseHudTheme.Muted))
    $panel = New-ProPanel $stack "10" "0,0,10,14"
    [System.Windows.Controls.Grid]::SetColumn($panel, [array]::IndexOf(@("HUD", "FOCUS", "TOOLS"), $item[0]))
    [void]$statusGrid.Children.Add($panel)
}
[void]$rootPanel.Children.Add($statusGrid)

$quickRow = New-Object System.Windows.Controls.WrapPanel
[void]$rootPanel.Children.Add($quickRow)

Add-ToolButton $quickRow "Pulse HUD" "Overlay de FPS, CPU, GPU e RAM." "src\OverlayLeve.ps1" -Sta
Add-ToolButton $quickRow "Configurar HUD" "Visual, hotkey, transparencia e modo taskbar." "src\ConfigurarOverlay.ps1" -Sta
Add-ToolButton $quickRow "Game Focus Mode" "Detecta jogos, muda energia, fecha apps e aplica prioridade." "src\GameFocusMode.ps1" -Sta
Add-ToolButton $quickRow "Game Launcher Profiles" "Abre jogos com apps, prioridade e limpeza de processos." "src\GameLauncherProfiles.ps1" -Sta
Add-ToolButton $quickRow "Game Library" "Varre, cataloga, abre e remove jogos com seguranca." "src\GameLibrary.ps1" -Sta
Add-ToolButton $quickRow "Clip Marker" "Hotkey para salvar timestamps de highlights." "src\ClipMarker.ps1" -Sta
Add-ToolButton $quickRow "Ping HUD" "Overlay de ping, perda e jitter." "src\PingHud.ps1" -Sta
Add-ToolButton $quickRow "Aim Warmup Timer" "Blocos de treino antes da partida." "src\AimWarmupTimer.ps1" -Sta
Add-ToolButton $quickRow "OBS Quick Deck" "Botoes visuais que disparam hotkeys no OBS." "src\ObsQuickDeck.ps1" -Sta
Add-ToolButton $quickRow "Thermal Alert" "Alertas de uso alto e temperatura quando o Windows expuser sensor." "src\ThermalAlert.ps1" -Sta
Add-ToolButton $quickRow "Game Notes Overlay" "Notas por jogo em overlay discreto." "src\GameNotesOverlay.ps1" -Sta
Add-ToolButton $quickRow "Brightness Control" "Controle gamer de brilho por DDC/CI e WMI." "src\BrightnessController.ps1" -Sta
Add-ToolButton $quickRow "Profile Editor" "Editor validado para modulos e perfis." "src\ProfileEditor.ps1" -Sta

$configButton = New-ProButton "Abrir editor de perfis" 190 36 "Primary"
$configButton.Margin = "0,8,0,0"
$configButton.HorizontalAlignment = "Left"
$configButton.Add_Click({ Start-ProScript "src\ProfileEditor.ps1" -Sta })
[void]$rootPanel.Children.Add($configButton)

$window.Content = $scroll
[void]$window.ShowDialog()
