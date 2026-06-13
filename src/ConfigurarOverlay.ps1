$ErrorActionPreference = "Stop"

# The configuration panel edits the same JSON file consumed by OverlayLeve.ps1.
$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot "config\settings.json"

# WPF is used here too, keeping the project dependency-free.
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

# Defaults mirror OverlayLeve.ps1 so the panel can recreate a missing config.
function Get-DefaultSettings {
    [pscustomobject]@{
        AppName = "Pulse HUD - FPS Overlay"
        Mode = "Overlay"
        X = 20
        Y = 20
        Width = 224
        Height = 116
        IntervalMs = 1000
        BackgroundColor = "#0D0F12"
        TextColor = "#FFFFFF"
        LabelColor = "#DCDCDC"
        AccentColor = "#7DD3FC"
        Opacity = 0.86
        FontSize = 16
        LabelFontSize = 12
        ClickThrough = $false
        ShowInTaskbar = $false
        StartWithWindows = $false
        ToggleHotkey = "Ctrl+Alt+O"
        FpsFile = "$env:TEMP\overlay_fps.txt"
        PresentMonCsv = ""
    }
}

# Load settings and merge newly added options into older config files.
function Get-Settings {
    $defaults = Get-DefaultSettings
    if (-not (Test-Path -LiteralPath $configPath)) { return $defaults }

    $settings = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    foreach ($prop in $defaults.PSObject.Properties.Name) {
        if (-not ($settings.PSObject.Properties.Name -contains $prop)) {
            $settings | Add-Member -NotePropertyName $prop -NotePropertyValue $defaults.$prop
        }
    }
    return $settings
}

# Save JSON in a human-editable format.
function Save-Settings {
    param($Settings)

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $configPath) | Out-Null
    $Settings | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8
}

# UI helper for left-column labels.
function New-Label {
    param([string]$Text)

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $Text
    $label.FontFamily = "Segoe UI"
    $label.FontSize = 12
    $label.Foreground = "#20242B"
    $label.VerticalAlignment = "Center"
    return $label
}

# Adds a labeled control to the settings grid.
function Add-Row {
    param($Grid, [int]$Row, [string]$Label, $Control)

    $Grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "36" }))
    $labelBlock = New-Label $Label
    [System.Windows.Controls.Grid]::SetRow($labelBlock, $Row)
    [System.Windows.Controls.Grid]::SetColumn($labelBlock, 0)
    [void]$Grid.Children.Add($labelBlock)

    [System.Windows.Controls.Grid]::SetRow($Control, $Row)
    [System.Windows.Controls.Grid]::SetColumn($Control, 1)
    [void]$Grid.Children.Add($Control)
}

# Text boxes are used for numeric fields and colors.
function New-TextBox {
    param([string]$Value)
    $box = New-Object System.Windows.Controls.TextBox
    $box.Text = $Value
    $box.Margin = "0,3,0,3"
    return $box
}

# Check boxes control binary options like startup and taskbar visibility.
function New-CheckBox {
    param([bool]$Checked)
    $box = New-Object System.Windows.Controls.CheckBox
    $box.IsChecked = $Checked
    $box.VerticalAlignment = "Center"
    return $box
}

# Build a compact configuration window.
$settings = Get-Settings

$window = New-Object System.Windows.Window
$window.Title = "Configurar $($settings.AppName)"
$window.Width = 520
$window.Height = 650
$window.WindowStartupLocation = "CenterScreen"
$window.Background = "#F4F6F8"

$scroll = New-Object System.Windows.Controls.ScrollViewer
$root = New-Object System.Windows.Controls.StackPanel
$root.Margin = "18"
$scroll.Content = $root

$title = New-Object System.Windows.Controls.TextBlock
$title.Text = "Configuracao do overlay"
$title.FontFamily = "Segoe UI"
$title.FontSize = 22
$title.FontWeight = "Bold"
$title.Margin = "0,0,0,12"
[void]$root.Children.Add($title)

$grid = New-Object System.Windows.Controls.Grid
$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "170" }))
$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))
[void]$root.Children.Add($grid)

$appName = New-TextBox $settings.AppName
$mode = New-Object System.Windows.Controls.ComboBox
@("Overlay", "Taskbar") | ForEach-Object { [void]$mode.Items.Add($_) }
$mode.SelectedItem = $settings.Mode
$width = New-TextBox ([string]$settings.Width)
$height = New-TextBox ([string]$settings.Height)
$interval = New-TextBox ([string]$settings.IntervalMs)
$bg = New-TextBox $settings.BackgroundColor
$text = New-TextBox $settings.TextColor
$label = New-TextBox $settings.LabelColor
$accent = New-TextBox $settings.AccentColor
$opacity = New-TextBox ([string]$settings.Opacity)
$font = New-TextBox ([string]$settings.FontSize)
$labelFont = New-TextBox ([string]$settings.LabelFontSize)
$hotkey = New-TextBox $settings.ToggleHotkey
$clickThrough = New-CheckBox ([bool]$settings.ClickThrough)
$showTaskbar = New-CheckBox ([bool]$settings.ShowInTaskbar)
$startup = New-CheckBox ([bool]$settings.StartWithWindows)

$script:row = 0
function Add-NextRow {
    param([string]$Label, $Control)

    Add-Row $grid $script:row $Label $Control
    $script:row++
}

Add-NextRow "Nome" $appName
Add-NextRow "Modo" $mode
Add-NextRow "Largura" $width
Add-NextRow "Altura" $height
Add-NextRow "Atualizacao (ms)" $interval
Add-NextRow "Fundo" $bg
Add-NextRow "Texto" $text
Add-NextRow "Rotulos" $label
Add-NextRow "Borda/acento" $accent
Add-NextRow "Transparencia" $opacity
Add-NextRow "Tamanho texto" $font
Add-NextRow "Tamanho rotulos" $labelFont
Add-NextRow "Atalho ocultar" $hotkey
Add-NextRow "Click-through" $clickThrough
Add-NextRow "Mostrar na barra" $showTaskbar
Add-NextRow "Iniciar com Windows" $startup

$buttons = New-Object System.Windows.Controls.StackPanel
$buttons.Orientation = "Horizontal"
$buttons.HorizontalAlignment = "Right"
$buttons.Margin = "0,18,0,0"

$save = New-Object System.Windows.Controls.Button
$save.Content = "Salvar"
$save.Width = 92
$save.Height = 34
$save.Margin = "0,0,8,0"

$close = New-Object System.Windows.Controls.Button
$close.Content = "Fechar"
$close.Width = 92
$close.Height = 34

[void]$buttons.Children.Add($save)
[void]$buttons.Children.Add($close)
[void]$root.Children.Add($buttons)

# Collect UI values and write them back to config/settings.json.
$save.Add_Click({
    $settings.AppName = $appName.Text
    $settings.Mode = [string]$mode.SelectedItem
    if ($settings.Mode -eq "Taskbar") {
        $showTaskbar.IsChecked = $true
    }
    $settings.Width = [int]$width.Text
    $settings.Height = [int]$height.Text
    $settings.IntervalMs = [int]$interval.Text
    $settings.BackgroundColor = $bg.Text
    $settings.TextColor = $text.Text
    $settings.LabelColor = $label.Text
    $settings.AccentColor = $accent.Text
    $settings.Opacity = [double]$opacity.Text
    $settings.FontSize = [double]$font.Text
    $settings.LabelFontSize = [double]$labelFont.Text
    $settings.ToggleHotkey = $hotkey.Text
    $settings.ClickThrough = [bool]$clickThrough.IsChecked
    $settings.ShowInTaskbar = [bool]$showTaskbar.IsChecked
    $settings.StartWithWindows = [bool]$startup.IsChecked
    Save-Settings $settings
    [System.Windows.MessageBox]::Show("Configuracao salva. O overlay aplica as mudancas sozinho em ate 1 segundo.", "OK") | Out-Null
})

$close.Add_Click({ $window.Close() })

$window.Content = $scroll
[void]$window.ShowDialog()
