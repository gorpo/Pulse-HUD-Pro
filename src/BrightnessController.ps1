$ErrorActionPreference = "Continue"
. "$PSScriptRoot\PulseHudProCommon.ps1"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class PulseBrightnessDisplay {
    public int Index { get; set; }
    public string Name { get; set; }
    public uint Min { get; set; }
    public uint Current { get; set; }
    public uint Max { get; set; }
    public bool Supported { get; set; }
    public string Source { get; set; }
}

public static class PulseBrightnessNative {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct PHYSICAL_MONITOR {
        public IntPtr hPhysicalMonitor;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szPhysicalMonitorDescription;
    }

    private delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, IntPtr lprcMonitor, IntPtr dwData);

    [DllImport("user32.dll")]
    private static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumProc lpfnEnum, IntPtr dwData);

    [DllImport("dxva2.dll", SetLastError = true)]
    private static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, out uint count);

    [DllImport("dxva2.dll", SetLastError = true)]
    private static extern bool GetPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, uint count, [Out] PHYSICAL_MONITOR[] monitors);

    [DllImport("dxva2.dll", SetLastError = true)]
    private static extern bool DestroyPhysicalMonitors(uint count, PHYSICAL_MONITOR[] monitors);

    [DllImport("dxva2.dll", SetLastError = true)]
    private static extern bool GetMonitorBrightness(IntPtr handle, out uint min, out uint current, out uint max);

    [DllImport("dxva2.dll", SetLastError = true)]
    private static extern bool SetMonitorBrightness(IntPtr handle, uint value);

    [DllImport("dxva2.dll", SetLastError = true)]
    private static extern bool GetVCPFeatureAndVCPFeatureReply(IntPtr handle, byte code, out uint type, out uint current, out uint maximum);

    [DllImport("dxva2.dll", SetLastError = true)]
    private static extern bool SetVCPFeature(IntPtr handle, byte code, uint value);

    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_TRANSPARENT = 0x00000020;
    public const int WS_EX_TOOLWINDOW = 0x00000080;

    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    private static List<PHYSICAL_MONITOR> monitors = new List<PHYSICAL_MONITOR>();

    public static PulseBrightnessDisplay[] GetDisplays() {
        DestroyAll();
        List<IntPtr> logical = new List<IntPtr>();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, delegate(IntPtr h, IntPtr dc, IntPtr rect, IntPtr data) {
            logical.Add(h);
            return true;
        }, IntPtr.Zero);

        foreach (IntPtr h in logical) {
            uint count;
            if (!GetNumberOfPhysicalMonitorsFromHMONITOR(h, out count) || count == 0) continue;
            PHYSICAL_MONITOR[] found = new PHYSICAL_MONITOR[count];
            if (!GetPhysicalMonitorsFromHMONITOR(h, count, found)) continue;
            monitors.AddRange(found);
        }

        List<PulseBrightnessDisplay> result = new List<PulseBrightnessDisplay>();
        for (int i = 0; i < monitors.Count; i++) {
            uint min = 0, current = 0, max = 100, type = 0;
            bool ok = GetVCPFeatureAndVCPFeatureReply(monitors[i].hPhysicalMonitor, 0x10, out type, out current, out max);
            string source = "DDC/CI";
            if (!ok) {
                ok = GetMonitorBrightness(monitors[i].hPhysicalMonitor, out min, out current, out max);
                source = "Windows";
            }
            result.Add(new PulseBrightnessDisplay {
                Index = i,
                Name = String.IsNullOrWhiteSpace(monitors[i].szPhysicalMonitorDescription) ? "Monitor " + (i + 1) : monitors[i].szPhysicalMonitorDescription,
                Min = min,
                Current = current,
                Max = max == 0 ? 100 : max,
                Supported = ok,
                Source = source
            });
        }
        return result.ToArray();
    }

    public static bool SetBrightness(int index, uint value) {
        if (index < 0 || index >= monitors.Count) return false;
        if (SetVCPFeature(monitors[index].hPhysicalMonitor, 0x10, value)) return true;
        return SetMonitorBrightness(monitors[index].hPhysicalMonitor, value);
    }

    public static void DestroyAll() {
        if (monitors.Count == 0) return;
        PHYSICAL_MONITOR[] arr = monitors.ToArray();
        DestroyPhysicalMonitors((uint)arr.Length, arr);
        monitors.Clear();
    }

    public static void MakeClickThrough(IntPtr hwnd) {
        int style = GetWindowLong(hwnd, GWL_EXSTYLE);
        SetWindowLong(hwnd, GWL_EXSTYLE, style | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW);
    }
}
"@

$config = (Get-ProProfiles).BrightnessController
$script:Displays = @()
$script:WmiDisplays = @()
$script:SuppressSlider = $false
$script:DimmerWindows = @()

Add-Type -AssemblyName System.Windows.Forms

function Get-WmiBrightnessDisplays {
    $items = @()
    try {
        $brightness = @(Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction Stop)
        for ($i = 0; $i -lt $brightness.Count; $i++) {
            $items += [pscustomobject]@{
                Index = $i
                Name = "Tela interna $($i + 1)"
                Min = 0
                Current = [uint32]$brightness[$i].CurrentBrightness
                Max = 100
                Supported = $true
                Source = "WMI"
                Wmi = $true
            }
        }
    } catch {}
    return $items
}

function Set-WmiBrightness {
    param([int]$Index, [int]$Percent)

    try {
        $methods = @(Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods -ErrorAction Stop)
        if ($Index -ge 0 -and $Index -lt $methods.Count) {
            Invoke-CimMethod -InputObject $methods[$Index] -MethodName WmiSetBrightness -Arguments @{ Timeout = 1; Brightness = [byte]$Percent } | Out-Null
            return $true
        }
    } catch {}
    return $false
}

function Convert-ToPercent {
    param($Display)
    if (-not $Display.Supported) { return 0 }
    $range = [Math]::Max(1, [double]$Display.Max - [double]$Display.Min)
    return [int]([Math]::Round((([double]$Display.Current - [double]$Display.Min) / $range) * 100))
}

function Convert-FromPercent {
    param($Display, [int]$Percent)
    $p = [Math]::Max(0, [Math]::Min(100, $Percent))
    return [uint32]([Math]::Round([double]$Display.Min + ((([double]$Display.Max - [double]$Display.Min) * $p) / 100)))
}

function Refresh-Displays {
    $script:Displays = @([PulseBrightnessNative]::GetDisplays())
    $script:WmiDisplays = @(Get-WmiBrightnessDisplays)
    $all = @($script:Displays + $script:WmiDisplays)
    $list.Items.Clear()
    foreach ($display in $all) {
        $status = if ($display.Supported) { "$(Convert-ToPercent $display)%" } else { "sem controle" }
        [void]$list.Items.Add("$($display.Name) [$($display.Source)] - $status")
    }
    if ($list.Items.Count -gt 0 -and $list.SelectedIndex -lt 0) { $list.SelectedIndex = 0 }
    Update-Selection
}

function Get-SelectedDisplay {
    $all = @($script:Displays + $script:WmiDisplays)
    if ($list.SelectedIndex -lt 0 -or $list.SelectedIndex -ge $all.Count) { return $null }
    return $all[$list.SelectedIndex]
}

function Set-SelectedBrightness {
    param([int]$Percent)

    $display = Get-SelectedDisplay
    if ($null -eq $display -or -not $display.Supported) { return }
    if ($display.PSObject.Properties.Name -contains "Wmi") {
        [void](Set-WmiBrightness $display.Index $Percent)
    } else {
        [void][PulseBrightnessNative]::SetBrightness($display.Index, (Convert-FromPercent $display $Percent))
    }
    Write-ProLog "brightness" "Set $($display.Name) to $Percent%"
    Refresh-Displays
}

function Hide-SoftwareDimmer {
    foreach ($dimmer in @($script:DimmerWindows)) {
        try { $dimmer.Close() } catch {}
    }
    $script:DimmerWindows = @()
    if ($dimmerStatus) { $dimmerStatus.Text = "Dimmer universal: desligado" }
}

function Show-SoftwareDimmer {
    param([int]$Percent)

    Hide-SoftwareDimmer
    $pct = [Math]::Max(0, [Math]::Min(75, $Percent))
    if ($pct -le 0) { return }

    foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
        $dimmer = New-Object System.Windows.Window
        $dimmer.Title = "Pulse HUD Pro Dimmer"
        $dimmer.WindowStyle = "None"
        $dimmer.ResizeMode = "NoResize"
        $dimmer.AllowsTransparency = $true
        $dimmer.Background = [System.Windows.Media.Brushes]::Black
        $dimmer.Opacity = $pct / 100
        $dimmer.Topmost = $true
        $dimmer.ShowInTaskbar = $false
        $dimmer.ShowActivated = $false
        $dimmer.Focusable = $false
        $dimmer.Left = $screen.Bounds.Left
        $dimmer.Top = $screen.Bounds.Top
        $dimmer.Width = $screen.Bounds.Width
        $dimmer.Height = $screen.Bounds.Height
        $dimmer.Add_SourceInitialized({
            $helper = New-Object System.Windows.Interop.WindowInteropHelper($this)
            [PulseBrightnessNative]::MakeClickThrough($helper.Handle)
        })
        $dimmer.Show()
        $script:DimmerWindows += $dimmer
    }

    $dimmerStatus.Text = "Dimmer universal: $pct% em $($script:DimmerWindows.Count) tela(s)"
}

function Update-Selection {
    $display = Get-SelectedDisplay
    if ($null -eq $display) {
        $status.Text = "Nenhum monitor encontrado."
        return
    }
    $percent = Convert-ToPercent $display
    $script:SuppressSlider = $true
    $slider.Value = $percent
    $script:SuppressSlider = $false
    $status.Text = "$($display.Name)`nFonte: $($display.Source)`nBrilho: $percent%`nDDC/CI precisa estar ativo no menu do monitor externo."
}

$window = New-Object System.Windows.Window
Set-ProWindowStyle $window "Pulse HUD Pro - Brightness Control" 540 560

$rootPanel = New-Object System.Windows.Controls.StackPanel
$rootPanel.Margin = "18"

$title = New-ProText "Brightness Control" 26 "Bold" $script:PulseHudTheme.Text
$rootPanel.Children.Add($title) | Out-Null

$subtitle = New-ProText "DDC/CI + WMI, com presets rapidos para setup gamer." 12 "Normal" $script:PulseHudTheme.Accent
$subtitle.Margin = "0,0,0,14"
$rootPanel.Children.Add($subtitle) | Out-Null

$list = New-Object System.Windows.Controls.ListBox
$list.Height = 96
$list.Background = $script:PulseHudTheme.PanelAlt
$list.Foreground = $script:PulseHudTheme.Text
$list.BorderBrush = $script:PulseHudTheme.Accent
$rootPanel.Children.Add($list) | Out-Null

$slider = New-Object System.Windows.Controls.Slider
$slider.Minimum = 0
$slider.Maximum = 100
$slider.TickFrequency = 5
$slider.IsSnapToTickEnabled = $false
$slider.Margin = "0,18,0,10"
$rootPanel.Children.Add($slider) | Out-Null

$presetPanel = New-Object System.Windows.Controls.WrapPanel
foreach ($preset in @($config.Presets)) {
    $button = New-ProButton "$preset%" 72 34
    $button.Tag = [int]$preset
    $button.Add_Click({ Set-SelectedBrightness ([int]$this.Tag) })
    $presetPanel.Children.Add($button) | Out-Null
}
$rootPanel.Children.Add($presetPanel) | Out-Null

$actions = New-Object System.Windows.Controls.WrapPanel
$apply = New-ProButton "Aplicar" 96 34 "Primary"
$apply.Add_Click({ Set-SelectedBrightness ([int]$slider.Value) })
$refresh = New-ProButton "Atualizar" 96 34
$refresh.Add_Click({ Refresh-Displays })
$actions.Children.Add($apply) | Out-Null
$actions.Children.Add($refresh) | Out-Null
$rootPanel.Children.Add($actions) | Out-Null

$dimmerPanel = New-Object System.Windows.Controls.StackPanel
$dimmerPanel.Margin = "0,8,0,0"
$dimmerTitle = New-ProText "Dimmer universal" 14 "Bold" $script:PulseHudTheme.Accent2
$dimmerInfo = New-ProText "Fallback visual para qualquer monitor. Ele escurece a tela por overlay e nao muda a luz de fundo real." 11 "Normal" $script:PulseHudTheme.Muted
$dimmerInfo.Margin = "0,2,0,8"
$dimmerSlider = New-Object System.Windows.Controls.Slider
$dimmerSlider.Minimum = 0
$dimmerSlider.Maximum = 75
$dimmerSlider.Value = [double]$config.SoftwareDimmerOpacity
$dimmerSlider.TickFrequency = 5
$dimmerSlider.Margin = "0,0,0,8"
$dimmerButtons = New-Object System.Windows.Controls.WrapPanel
$dimmerApply = New-ProButton "Ativar dimmer" 124 34 "Primary"
$dimmerOff = New-ProButton "Desligar" 96 34
$dimmerStatus = New-ProText "Dimmer universal: desligado" 12 "Normal" $script:PulseHudTheme.Muted
$dimmerApply.Add_Click({ Show-SoftwareDimmer ([int]$dimmerSlider.Value) })
$dimmerOff.Add_Click({ $dimmerSlider.Value = 0; Hide-SoftwareDimmer })
$dimmerButtons.Children.Add($dimmerApply) | Out-Null
$dimmerButtons.Children.Add($dimmerOff) | Out-Null
$dimmerPanel.Children.Add($dimmerTitle) | Out-Null
$dimmerPanel.Children.Add($dimmerInfo) | Out-Null
$dimmerPanel.Children.Add($dimmerSlider) | Out-Null
$dimmerPanel.Children.Add($dimmerButtons) | Out-Null
$dimmerPanel.Children.Add($dimmerStatus) | Out-Null
$rootPanel.Children.Add((New-ProPanel $dimmerPanel "12" "0,8,0,12")) | Out-Null

$status = New-Object System.Windows.Controls.TextBlock
$status.FontFamily = "Segoe UI"
$status.FontSize = 12
$status.Foreground = $script:PulseHudTheme.Muted
$status.TextWrapping = "Wrap"
$status.Margin = "0,8,0,0"
$rootPanel.Children.Add($status) | Out-Null

$list.Add_SelectionChanged({ Update-Selection })
$slider.Add_ValueChanged({
    if (-not $script:SuppressSlider) {
        $status.Text = "Selecionado: {0:N0}%" -f $slider.Value
    }
})

$window.Content = $rootPanel
$window.Add_Loaded({ Refresh-Displays })
$window.Add_Closed({
    Hide-SoftwareDimmer
    [PulseBrightnessNative]::DestroyAll()
})
[void]$window.ShowDialog()
