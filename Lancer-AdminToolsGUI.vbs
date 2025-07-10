Set objShell = CreateObject("Wscript.Shell")
' Chemin du dossier où se trouve ce VBS
Set fso = CreateObject("Scripting.FileSystemObject")
currentDir = fso.GetParentFolderName(WScript.ScriptFullName)
' Chemin du script PowerShell à lancer (relatif au VBS)
scriptPath = currentDir & "\AdminToolsGUI\AdminToolsGUI-WPF\ScriptAdminGUI-WPF.ps1"
' Chemin de PowerShell 7
pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
' Commande à exécuter
cmd = """" & pwshPath & """ -WindowStyle Hidden -File """ & scriptPath & """"
objShell.Run cmd, 0, False 