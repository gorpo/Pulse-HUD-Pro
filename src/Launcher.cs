using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Windows.Forms;

internal static class Launcher
{
    // One tiny executable is reused for app/config/install/uninstall. Its own
    // file name decides which PowerShell script to run.
    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            string exePath = Application.ExecutablePath;
            string exeName = Path.GetFileNameWithoutExtension(exePath).ToLowerInvariant();
            string root = FindProjectRoot(Path.GetDirectoryName(exePath));
            string script;
            string extraArgs = string.Join(" ", args.Select(Quote));
            bool hidden = true;

            switch (exeName)
            {
                case "pulsehudpro":
                case "pulse hud pro":
                    script = Path.Combine(root, "src", "PulseHudPro.ps1");
                    hidden = false;
                    break;
                case "pulsehudconfig":
                case "pulse hud - fps overlay config":
                    script = Path.Combine(root, "src", "ConfigurarOverlay.ps1");
                    hidden = false;
                    break;
                case "pulsehudinstall":
                case "pulse hud - fps overlay installer":
                    script = Path.Combine(root, "scripts", "Instalar.ps1");
                    hidden = false;
                    break;
                case "pulsehuduninstall":
                case "pulse hud - fps overlay uninstaller":
                    script = Path.Combine(root, "scripts", "Desinstalar.ps1");
                    hidden = false;
                    extraArgs = (extraArgs + " -InstalledMode").Trim();
                    break;
                default:
                    script = Path.Combine(root, "src", "OverlayLeve.ps1");
                    break;
            }

            if (!File.Exists(script))
            {
                MessageBox.Show("Script nao encontrado:\n" + script, "Pulse HUD Pro", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 2;
            }

            ProcessStartInfo info = new ProcessStartInfo();
            info.FileName = "powershell.exe";
            info.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -File " + Quote(script) + (extraArgs.Length > 0 ? " " + extraArgs : "");
            info.WorkingDirectory = root;
            info.UseShellExecute = false;
            info.CreateNoWindow = hidden;
            info.WindowStyle = hidden ? ProcessWindowStyle.Hidden : ProcessWindowStyle.Normal;

            Process.Start(info);
            return 0;
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "Pulse HUD Pro", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    private static string FindProjectRoot(string start)
    {
        string dir = start;
        while (!string.IsNullOrEmpty(dir))
        {
            if (Directory.Exists(Path.Combine(dir, "src")) && Directory.Exists(Path.Combine(dir, "scripts")))
            {
                return dir;
            }
            dir = Directory.GetParent(dir) == null ? null : Directory.GetParent(dir).FullName;
        }

        return start;
    }

    private static string Quote(string value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return "\"\"";
        }
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }
}
