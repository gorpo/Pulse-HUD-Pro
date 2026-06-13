$ErrorActionPreference = "Continue"
. "$PSScriptRoot\PulseHudProCommon.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class ClipMarkerHotkey {
  public const int WM_HOTKEY = 0x0312;
  [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
  [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
"@

function Convert-Hotkey {
    param([string]$Text)
    $mods = 0
    $key = "M"
    foreach ($part in ($Text -split "\+")) {
        switch -Regex ($part.Trim()) {
            "Ctrl|Control" { $mods = $mods -bor 0x0002; continue }
            "Alt" { $mods = $mods -bor 0x0001; continue }
            "Shift" { $mods = $mods -bor 0x0004; continue }
            "Win" { $mods = $mods -bor 0x0008; continue }
            default { $key = $part.Trim().ToUpperInvariant() }
        }
    }
    Add-Type -AssemblyName System.Windows.Forms
    [pscustomobject]@{ Mods = $mods; Key = [int][System.Enum]::Parse([System.Windows.Forms.Keys], $key, $true) }
}

$config = (Get-ProProfiles).ClipMarker
$out = Resolve-ProPath $config.OutputCsv
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
if (-not (Test-Path -LiteralPath $out)) {
    "LocalTime,UnixTime,Note" | Set-Content -LiteralPath $out -Encoding UTF8
}

function Add-Marker {
    param([string]$Note = "")
    $now = Get-Date
    $unix = [DateTimeOffset]::new($now).ToUnixTimeSeconds()
    Add-Content -LiteralPath $out -Value ('"{0}",{1},"{2}"' -f $now.ToString("yyyy-MM-dd HH:mm:ss"), $unix, ($Note -replace '"','""')) -Encoding UTF8
    $script:last.Text = "Ultimo marker: $($now.ToString('HH:mm:ss'))"
}

$window = New-Object System.Windows.Window
Set-ProWindowStyle $window "Clip Marker" 460 250 -Topmost
$panel = New-Object System.Windows.Controls.StackPanel
$panel.Margin = "14"
$title = New-ProText "CLIP MARKER" 16 "Bold" $script:PulseHudTheme.Accent
$title.Margin = "0,0,0,10"
$info = New-ProText "Hotkey global: $($config.Hotkey)`nSaida: $out" 12 "Normal" $script:PulseHudTheme.Muted
$note = New-Object System.Windows.Controls.TextBox
$note.Margin = "0,12,0,8"
$note.Height = 28
$note.Text = ""
$note.Background = $script:PulseHudTheme.PanelAlt
$note.Foreground = $script:PulseHudTheme.Text
$note.BorderBrush = $script:PulseHudTheme.Accent
$button = New-ProButton "Marcar agora" 130 34 "Primary"
$script:last = New-ProText "" 12 "Normal" $script:PulseHudTheme.Success
$script:last.Margin = "0,10,0,0"
$button.Add_Click({ Add-Marker $note.Text })
$panel.Children.Add($title) | Out-Null
$panel.Children.Add($info) | Out-Null
$panel.Children.Add($note) | Out-Null
$panel.Children.Add($button) | Out-Null
$panel.Children.Add($script:last) | Out-Null
$window.Content = New-ProPanel $panel "14" "0"

$hotkeyId = 9101
$window.Add_SourceInitialized({
    $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
    $script:handle = $helper.Handle
    $hk = Convert-Hotkey $config.Hotkey
    [ClipMarkerHotkey]::RegisterHotKey($script:handle, $hotkeyId, [uint32]$hk.Mods, [uint32]$hk.Key) | Out-Null
    $src = [System.Windows.Interop.HwndSource]::FromHwnd($script:handle)
    $src.AddHook({
        param($hwnd, $msg, $wParam, $lParam, [ref]$handled)
        if ($msg -eq [ClipMarkerHotkey]::WM_HOTKEY -and $wParam.ToInt32() -eq $hotkeyId) {
            Add-Marker $note.Text
            $handled.Value = $true
        }
        return [IntPtr]::Zero
    })
})
$window.Add_Closed({ if ($script:handle) { [ClipMarkerHotkey]::UnregisterHotKey($script:handle, $hotkeyId) | Out-Null } })
[void]$window.ShowDialog()
