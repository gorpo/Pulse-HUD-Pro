Option Explicit

' Visible launcher for the graphical settings panel.
Dim shell, fso, scriptDir, rootDir, command

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
rootDir = fso.GetParentFolderName(scriptDir)

' The settings panel is intentionally visible, so the window style is normal.
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File """ & rootDir & "\src\ConfigurarOverlay.ps1"""

shell.Run command, 1, False
