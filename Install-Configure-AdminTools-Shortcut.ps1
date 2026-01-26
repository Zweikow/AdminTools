#Requires -RunAsAdministrator

# Script d'installation et de configuration d'AdminTools
# 1. Verifie et installe PowerShell 7 si necessaire
# 2. Definit PowerShell 7 comme version par defaut
# 3. Cree un raccourci sur le bureau

Write-Host "=== Installation et Configuration d'AdminTools ===" -ForegroundColor Cyan
Write-Host ""

# ===== ETAPE 1 : Verifier et installer PowerShell 7 =====
Write-Host "[1/3] Verification de PowerShell 7..." -ForegroundColor Yellow

$pwsh7Path = "C:\Program Files\PowerShell\7\pwsh.exe"

if (Test-Path $pwsh7Path) {
    Write-Host "[OK] PowerShell 7 est deja installe" -ForegroundColor Green
    $pwshVersion = & $pwsh7Path -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
    Write-Host "  Version detectee : $pwshVersion" -ForegroundColor Gray
} else {
    Write-Host "[X] PowerShell 7 n'est pas installe" -ForegroundColor Red
    Write-Host "  Installation de PowerShell 7 en cours..." -ForegroundColor Yellow
    
    try {
        # Installation via winget (methode recommandee)
        Write-Host "  Tentative d'installation via winget..." -ForegroundColor Gray
        $result = winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1
        
        if (Test-Path $pwsh7Path) {
            Write-Host "[OK] PowerShell 7 installe avec succes" -ForegroundColor Green
        } else {
            throw "L'installation via winget a echoue"
        }
    } catch {
        Write-Host "  Erreur lors de l'installation : $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Installation manuelle requise :" -ForegroundColor Yellow
        Write-Host "1. Telechargez PowerShell 7 depuis : https://aka.ms/powershell-release?tag=stable" -ForegroundColor White
        Write-Host "2. Installez-le et relancez ce script" -ForegroundColor White
        Write-Host ""
        Read-Host "Appuyez sur Entree pour quitter"
        exit 1
    }
}

Write-Host ""

# ===== ETAPE 2 : Definir PowerShell 7 comme version par defaut =====
Write-Host "[2/3] Configuration de PowerShell 7 comme version par defaut..." -ForegroundColor Yellow

try {
    # Modification de l'association par defaut pour les fichiers .ps1
    cmd /c ftype Microsoft.PowerShellScript.1="`"$pwsh7Path`" -NoLogo -ExecutionPolicy Bypass -File `"%1`"" 2>$null
    
    Write-Host "[OK] PowerShell 7 defini comme interpreteur par defaut pour les scripts .ps1" -ForegroundColor Green
} catch {
    Write-Host "[!] Impossible de definir PowerShell 7 par defaut : $_" -ForegroundColor Yellow
    Write-Host "  Le programme fonctionnera quand meme car le VBS specifie pwsh.exe" -ForegroundColor Gray
}

Write-Host ""

# ===== ETAPE 3 : Creer le raccourci sur le bureau =====
Write-Host "[3/3] Creation du raccourci sur le bureau..." -ForegroundColor Yellow

# Detection automatique du dossier d'installation
$installPath = $PSScriptRoot
Write-Host "  Dossier d'installation detecte : $installPath" -ForegroundColor Gray

$desktop = [Environment]::GetFolderPath('Desktop')
$target = Join-Path $installPath "src\Lancer-AdminToolsGUI.vbs"
$icon = Join-Path $installPath "src\Computer-Doctor.ico"
$shortcutPath = Join-Path $desktop "AdminTools.lnk"

Write-Host "  Fichier cible : $target" -ForegroundColor Gray
Write-Host "  Icone : $icon" -ForegroundColor Gray

# Verification que les fichiers source existent
if (-not (Test-Path $target)) {
    Write-Host "[X] Erreur : Le fichier $target n'existe pas" -ForegroundColor Red
    Write-Host "  Assurez-vous que AdminTools est correctement installe" -ForegroundColor Yellow
    Read-Host "Appuyez sur Entree pour quitter"
    exit 1
}

if (-not (Test-Path $icon)) {
    Write-Host "[!] Avertissement : L'icone $icon n'existe pas" -ForegroundColor Yellow
    $icon = $null
}

# Creation du raccourci
try {
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $target
    $shortcut.WorkingDirectory = Split-Path $target
    if ($icon) {
        $shortcut.IconLocation = $icon
    }
    $shortcut.Save()
    
    Write-Host "[OK] Raccourci cree : $shortcutPath" -ForegroundColor Green
} catch {
    Write-Host "[X] Erreur lors de la creation du raccourci : $_" -ForegroundColor Red
    Read-Host "Appuyez sur Entree pour quitter"
    exit 1
}

Write-Host ""
Write-Host "=== Installation terminee avec succes ! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Pour epingler a la barre des taches :" -ForegroundColor Cyan
Write-Host "  > Clic droit sur le raccourci 'AdminTools' du bureau" -ForegroundColor White
Write-Host "  > 'Epingler a la barre des taches'" -ForegroundColor White
Write-Host ""
Read-Host "Appuyez sur Entree pour fermer"
