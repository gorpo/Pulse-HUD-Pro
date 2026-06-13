$ErrorActionPreference = "Continue"
. "$PSScriptRoot\PulseHudProCommon.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class GameNotesHotkey {
  public const int WM_HOTKEY = 0x0312;
  [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
  [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
"@

$config = (Get-ProProfiles).GameNotesOverlay
$notes = @($config.Notes)

function Convert-Hotkey {
    param([string]$Text)
    $mods = 0
    $key = "N"
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

function Toggle-NotesOverlay {
    if ($window.IsVisible) {
        $window.Hide()
    } else {
        $window.Show()
        $window.Activate()
    }
}

$window = New-Object System.Windows.Window
Set-ProWindowStyle $window "Game Notes Overlay" 380 250 -Topmost -Overlay
$window.Left = 40
$window.Top = 330

$panel = New-Object System.Windows.Controls.StackPanel
$header = New-ProText "GAME NOTES  $($config.Hotkey)" 12 "Bold" $script:PulseHudTheme.Accent
$header.Margin = "0,0,0,8"
$text = New-ProText "" 14 "Normal" $script:PulseHudTheme.Text
[void]$panel.Children.Add($header)
[void]$panel.Children.Add($text)
$window.Content = New-ProPanel $panel "12" "0"
$window.Add_MouseLeftButtonDown({ try { $window.DragMove() } catch {} })

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(2)
$timer.Add_Tick({
    $match = $null
    foreach ($note in $notes) {
        if (Get-Process -Name $note.ProcessName -ErrorAction SilentlyContinue) { $match = $note; break }
    }
    if ($null -eq $match -and $notes.Count -gt 0) { $match = $notes[0] }
    if ($match) { $text.Text = "$($match.Game)`n`n$($match.Text)" }
})
$timer.Start()
$hotkeyId = 9301
$window.Add_SourceInitialized({
    $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
    $script:handle = $helper.Handle
    $hotkey = Convert-Hotkey $config.Hotkey
    [GameNotesHotkey]::RegisterHotKey($script:handle, $hotkeyId, [uint32]$hotkey.Mods, [uint32]$hotkey.Key) | Out-Null
    $source = [System.Windows.Interop.HwndSource]::FromHwnd($script:handle)
    $source.AddHook({
        param($hwnd, $msg, $wParam, $lParam, [ref]$handled)
        if ($msg -eq [GameNotesHotkey]::WM_HOTKEY -and $wParam.ToInt32() -eq $hotkeyId) {
            Toggle-NotesOverlay
            $handled.Value = $true
        }
        return [IntPtr]::Zero
    })
})
$window.Add_Closed({
    if ($script:handle) {
        [GameNotesHotkey]::UnregisterHotKey($script:handle, $hotkeyId) | Out-Null
    }
})
[void]$window.ShowDialog()
