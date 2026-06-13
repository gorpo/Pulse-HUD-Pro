Option Explicit

' Hidden launcher used by shortcuts. It starts PowerShell without a console.
Dim shell, fso, scriptDir, rootDir, command

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
rootDir = fso.GetParentFolderName(scriptDir)

' -STA is required by WPF; -WindowStyle Hidden keeps the console invisible.
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & rootDir & "\src\OverlayLeve.ps1"""

shell.Run command, 0, False
