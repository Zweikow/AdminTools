#Requires -RunAsAdministrator

# Script d'installation et de configuration d'AdminTools
# 1. Vérifie et installe PowerShell 7 si nécessaire
# 2. Définit PowerShell 7 comme version par défaut
# 3. Crée un raccourci sur le bureau

Write-Host "=== Installation et Configuration d'AdminTools ===" -ForegroundColor Cyan
Write-Host ""

# ===== ÉTAPE 1 : Vérifier et installer PowerShell 7 =====
Write-Host "[1/3] Vérification de PowerShell 7..." -ForegroundColor Yellow

$pwsh7Path = "C:\Program Files\PowerShell\7\pwsh.exe"

if (Test-Path $pwsh7Path) {
    Write-Host "✓ PowerShell 7 est déjà installé" -ForegroundColor Green
    $pwshVersion = & $pwsh7Path -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
    Write-Host "  Version détectée : $pwshVersion" -ForegroundColor Gray
} else {
    Write-Host "✗ PowerShell 7 n'est pas installé" -ForegroundColor Red
    Write-Host "  Installation de PowerShell 7 en cours..." -ForegroundColor Yellow
    
    try {
        # Installation via winget (méthode recommandée)
        Write-Host "  Tentative d'installation via winget..." -ForegroundColor Gray
        $result = winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1
        
        if (Test-Path $pwsh7Path) {
            Write-Host "✓ PowerShell 7 installé avec succès" -ForegroundColor Green
        } else {
            throw "L'installation via winget a échoué"
        }
    } catch {
        Write-Host "  Erreur lors de l'installation : $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Installation manuelle requise :" -ForegroundColor Yellow
        Write-Host "1. Téléchargez PowerShell 7 depuis : https://aka.ms/powershell-release?tag=stable" -ForegroundColor White
        Write-Host "2. Installez-le et relancez ce script" -ForegroundColor White
        Write-Host ""
        Read-Host "Appuyez sur Entrée pour quitter"
        exit 1
    }
}

Write-Host ""

# ===== ÉTAPE 2 : Définir PowerShell 7 comme version par défaut =====
Write-Host "[2/3] Configuration de PowerShell 7 comme version par défaut..." -ForegroundColor Yellow

try {
    # Création d'une association de fichier .ps1 avec PowerShell 7
    $pwsh7PathEscaped = $pwsh7Path -replace '\\', '\\'
    
    # Modification de l'association par défaut pour les fichiers .ps1
    & ftype Microsoft.PowerShellScript.1="`"$pwsh7Path`" -NoLogo -ExecutionPolicy Bypass -File `"%1`""
    
    Write-Host "✓ PowerShell 7 défini comme interpréteur par défaut pour les scripts .ps1" -ForegroundColor Green
} catch {
    Write-Host "⚠ Impossible de définir PowerShell 7 par défaut : $_" -ForegroundColor Yellow
    Write-Host "  Le programme fonctionnera quand même car le VBS spécifie pwsh.exe" -ForegroundColor Gray
}

Write-Host ""

# ===== ÉTAPE 3 : Créer le raccourci sur le bureau =====
Write-Host "[3/3] Création du raccourci sur le bureau..." -ForegroundColor Yellow

$desktop = [Environment]::GetFolderPath('Desktop')
$target = "C:\tools\src\Lancer-AdminToolsGUI.vbs"
$icon = "C:\tools\src\Computer-Doctor.ico"
$shortcutPath = Join-Path $desktop "AdminTools.lnk"

# Vérification que les fichiers source existent
if (-not (Test-Path $target)) {
    Write-Host "✗ Erreur : Le fichier $target n'existe pas" -ForegroundColor Red
    Write-Host "  Assurez-vous que AdminTools est installé dans C:\tools\" -ForegroundColor Yellow
    Read-Host "Appuyez sur Entrée pour quitter"
    exit 1
}

if (-not (Test-Path $icon)) {
    Write-Host "⚠ Avertissement : L'icône $icon n'existe pas" -ForegroundColor Yellow
    $icon = $null
}

# Création du raccourci
try {
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $target
    $shortcut.WorkingDirectory = Split-Path $target
    if ($icon) {
        $shortcut.IconLocation = $icon
    }
    $shortcut.Save()
    
    Write-Host "✓ Raccourci créé : $shortcutPath" -ForegroundColor Green
} catch {
    Write-Host "✗ Erreur lors de la création du raccourci : $_" -ForegroundColor Red
    Read-Host "Appuyez sur Entrée pour quitter"
    exit 1
}

Write-Host ""
Write-Host "=== Installation terminée avec succès ! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Pour épingler à la barre des tâches :" -ForegroundColor Cyan
Write-Host "  → Clic droit sur le raccourci 'AdminTools' du bureau" -ForegroundColor White
Write-Host "  → 'Épingler à la barre des tâches'" -ForegroundColor White
Write-Host ""
Read-Host "Appuyez sur Entrée pour fermer" 