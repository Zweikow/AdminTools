# AdminTools

## Présentation

**AdminTools** est un outil d'administration pour Windows permettant de faciliter la gestion à distance des postes de travail dans un environnement Active Directory. Il propose une interface graphique moderne (WPF) pour simplifier les tâches d'administration quotidiennes.

---

## Fonctionnalités principales

- **Recherche Active Directory** : Trouver rapidement un ordinateur par nom, IP ou description (filtrage en temps réel)
- **Session PowerShell distante** : Ouvre une session PowerShell sur le poste sélectionné (via Windows Terminal, avec élévation UAC)
- **Assistance à distance (MSRA)** : Lance l'outil d'assistance à distance Microsoft pour aider un utilisateur
- **Session RDP** : Génère un fichier RDP personnalisé, le déplace dans `C:\temp\RDP`, puis ouvre la connexion Bureau à distance
- **Gestion de l'ordinateur** : Ouvre la MMC de gestion de l'ordinateur distant en mode administrateur
- **Connexion au disque C: (admin)** : Ouvre l'explorateur sur le partage C$ distant (`\\nom_machine\C$`)
- **Interface graphique moderne (WPF)** : Utilisation simple et intuitive, adaptée à l'administration quotidienne

---

## Prérequis

- Windows 10/11
- PowerShell 7 (pwsh.exe) - sera installé automatiquement par le script si absent
- Module PowerShell ActiveDirectory (RSAT)
- Accès administrateur sur les postes distants pour certaines fonctions
- Droit d'exécution à distance (WinRM activé pour PowerShell distant)
- Microsoft Remote Assistance (MSRA) installé
- Windows Terminal (`wt.exe`) pour la session PowerShell moderne

---

## Installation

### Installation automatique (recommandée)

1. **Cloner le dépôt dans `C:\tools`**
   ```powershell
   # Créer le dossier si nécessaire
   New-Item -Path "C:\tools" -ItemType Directory -Force
   
   # Cloner le projet
   cd C:\tools
   git clone https://github.com/Zweikow/AdminTools.git .
   ```

2. **Lancer le script d'installation**
   
   Exécutez le script `Install-Configure-AdminTools-Shortcut.ps1` **en tant qu'administrateur** :
   ```powershell
   # Clic droit → "Exécuter avec PowerShell" en tant qu'administrateur
   C:\tools\Install-Configure-AdminTools-Shortcut.ps1
   ```
   
   Ce script effectue automatiquement :
   - ✅ Vérification et installation de PowerShell 7 (si absent)
   - ✅ Configuration de PowerShell 7 comme version par défaut
   - ✅ Création du raccourci sur le bureau avec icône personnalisée
   
   Une fois terminé, un raccourci **AdminTools** apparaît sur votre bureau !

3. **Installer les prérequis Windows**
   - Activer les outils d'administration RSAT (Active Directory) :
     ```powershell
     Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
     ```
   - Vérifier que WinRM est activé sur les postes distants :
     ```powershell
     Enable-PSRemoting -Force
     ```
   - Installer Windows Terminal (Microsoft Store) - normalement déjà présent sur Windows 11

4. **Utiliser l'application**
   - Double-cliquez sur le raccourci **AdminTools** créé sur le bureau
   - Optionnel : Clic droit sur le raccourci → "Épingler à la barre des tâches"

### Installation manuelle

Si vous préférez une installation manuelle :

1. Installez PowerShell 7 : [Télécharger PowerShell 7](https://aka.ms/powershell-release?tag=stable)
2. Clonez le dépôt dans `C:\tools`
3. Créez manuellement un raccourci pointant vers `C:\tools\src\Lancer-AdminToolsGUI.vbs`

---

## Utilisation

### Méthode recommandée (Interface graphique WPF)

1. **Double-cliquez sur le raccourci "AdminTools"** créé sur votre bureau
   - L'application se lance automatiquement sans fenêtre de terminal visible
   - L'interface graphique s'ouvre avec l'icône personnalisée

2. **Rechercher un ordinateur**
   - Tapez dans la barre de recherche : nom d'ordinateur, IP ou description
   - Les résultats s'affichent en temps réel dans le tableau

3. **Sélectionner et agir**
   - Cliquez sur un ordinateur dans le tableau
   - Utilisez les boutons pour lancer les actions souhaitées :
     - Session PowerShell distante
     - Assistance à distance (MSRA)
     - Connexion RDP
     - Gestion de l'ordinateur
     - Accès au disque C$ (admin)

### Méthode alternative (manuelle)

Si vous n'avez pas utilisé le script d'installation :

1. Ouvrez une console PowerShell 7 en tant qu'administrateur
2. Lancez directement le script principal :
   ```powershell
   C:\tools\src\ScriptAdminGUI-WPF.ps1
   ```

---

## Structure du projet

```
C:\tools\AdminTools\
├── README.md                                    # Documentation
├── Install-Configure-AdminTools-Shortcut.ps1    # Script d'installation
└── src/
    ├── Lancer-AdminToolsGUI.vbs                 # Lanceur VBS (sans terminal)
    ├── ScriptAdminGUI-WPF.ps1                   # Application principale
    └── Computer-Doctor.ico                      # Icône du raccourci
```

---

## Limitations & Conseils

- Certaines fonctions nécessitent des droits administrateur sur la machine distante
- Pour la session PowerShell distante, WinRM doit être activé sur la cible
- Le partage C$ doit être accessible et l'utilisateur doit avoir les droits nécessaires
- L'authentification sur le partage C$ se fait via la fenêtre Windows standard si besoin

---

## Auteurs

- Projet développé par [Zweikow](https://github.com/Zweikow) et contributeurs

---

## Licence

Ce projet est distribué sous licence MIT.
