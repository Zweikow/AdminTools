Set objShell = CreateObject("Wscript.Shell")
' Chemin du script PowerShell à lancer
scriptPath = "C:\tools\src\ScriptAdminGUI-WPF.ps1"
' Chemin de PowerShell 7
pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
' Commande à exécuter
cmd = """" & pwshPath & """ -WindowStyle Hidden -File """ & scriptPath & """"
objShell.Run cmd, 0, False 