Set objShell = CreateObject("Wscript.Shell")
' Chemin du script PowerShell à lancer
scriptPath = "C:\tools\AdminTools\src\ScriptAdminGUI-WPF.ps1"
' Chemin de PowerShell 7
pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
' Commande à exécuter avec -NoProfile pour demarrage plus rapide
cmd = """" & pwshPath & """ -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & scriptPath & """"
objShell.Run cmd, 0, False 