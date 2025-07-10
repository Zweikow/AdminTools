# Crée un raccourci sur le bureau pour lancer l'application AdminToolsGUI-WPF

# Chemin du script à lancer
$scriptPath = "C:\dev\AdminTools\AdminToolsGUI\AdminToolsGUI-WPF\ScriptAdminGUI-WPF.ps1"

# Chemin de PowerShell 7 (adapte si besoin)
$powershellExe = "C:\Program Files\PowerShell\7\pwsh.exe"

# Chemin du raccourci à créer (sur le bureau)
$shortcutPath = [System.IO.Path]::Combine([Environment]::GetFolderPath("Desktop"), "AdminToolsGUI.lnk")

# Crée l'objet WScript.Shell
$WshShell = New-Object -ComObject WScript.Shell

# Crée le raccourci
$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $powershellExe
$shortcut.Arguments = "-NoExit -File `"$scriptPath`""
$shortcut.WorkingDirectory = [System.IO.Path]::GetDirectoryName($scriptPath)
$shortcut.IconLocation = "$powershellExe,0"
$shortcut.Save()

Write-Host "Raccourci créé sur le bureau : $shortcutPath"
Write-Host "Pour l'épingler à la barre des tâches, fais un clic droit sur le raccourci puis 'Épingler à la barre des tâches'." 