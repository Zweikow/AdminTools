# Crée un raccourci sur le bureau pour lancer l'application AdminToolsGUI-WPF

# Chemin du bureau de l'utilisateur
$desktop = [Environment]::GetFolderPath('Desktop')

# Chemin du script VBS à lancer
$target = "$PSScriptRoot\..\..\Lancer-AdminToolsGUI.vbs"

# Chemin de l'icône
$icon = "$PSScriptRoot\Computer-Doctor.ico"

# Chemin du raccourci à créer
$shortcutPath = Join-Path $desktop "AdminTools.lnk"

# Création du raccourci
$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $target
$shortcut.WorkingDirectory = Split-Path $target
$shortcut.IconLocation = $icon
$shortcut.Save()

Write-Host "Raccourci créé sur le bureau : $shortcutPath"
Write-Host "Pour l'épingler à la barre des tâches, fais un clic droit sur le raccourci puis 'Épingler à la barre des tâches'." 