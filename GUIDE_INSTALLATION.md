# 📋 Guide d'installation - AdminTools

## Guide complet d'installation de A à Z

Ce document décrit toutes les étapes nécessaires pour installer AdminTools sur un poste de travail Windows.

---

## ⚙️ Configuration requise

Avant de commencer, assurez-vous que le poste répond aux exigences suivantes :

- **Système d'exploitation** : Windows 10 (version 1809 ou ultérieure) ou Windows 11
- **Droits utilisateur** : Compte administrateur local requis pour l'installation
- **Connexion Internet** : Nécessaire pour télécharger PowerShell 7 et cloner le dépôt Git
- **Git** : Doit être installé sur le poste ([Télécharger Git](https://git-scm.com/downloads))

---

## 📥 Étape 1 : Télécharger le projet

### Option A : Cloner avec Git (recommandé)

1. **Ouvrir PowerShell en tant qu'administrateur**
   - Clic droit sur le menu Démarrer → "Terminal (Admin)" ou "Windows PowerShell (Admin)"

2. **Créer le répertoire d'installation**
   ```powershell
   New-Item -Path "C:\tools" -ItemType Directory -Force
   ```

3. **Cloner le dépôt GitHub**
   ```powershell
   cd C:\tools
   git clone https://github.com/Zweikow/AdminTools.git
   ```

4. **Passer sur la branche de développement** (si nécessaire)
   ```powershell
   cd AdminTools
   git checkout dev
   ```

### Option B : Télécharger en ZIP

1. Aller sur : https://github.com/Zweikow/AdminTools
2. Cliquer sur le bouton vert **"Code"** → **"Download ZIP"**
3. Extraire le contenu dans `C:\tools\AdminTools\`

---

## 🚀 Étape 2 : Exécuter le script d'installation

1. **Naviguer vers le dossier du projet**
   ```powershell
   cd C:\tools\AdminTools
   ```

2. **Lancer le script d'installation en administrateur**
   
   **Méthode 1 - Via PowerShell (déjà ouvert en admin)**
   ```powershell
   .\Install-Configure-AdminTools-Shortcut.ps1
   ```
   
   **Méthode 2 - Via l'explorateur Windows**
   - Ouvrir l'explorateur → `C:\tools\AdminTools`
   - Clic droit sur `Install-Configure-AdminTools-Shortcut.ps1`
   - Choisir **"Exécuter avec PowerShell"**
   - Accepter l'élévation de privilèges (UAC)

3. **Suivre les étapes à l'écran**

   Le script va automatiquement :
   - ✅ Vérifier la présence de PowerShell 7
   - ✅ Installer PowerShell 7 via `winget` si nécessaire (~5 minutes)
   - ✅ Configurer PowerShell 7 comme version par défaut pour les fichiers `.ps1`
   - ✅ Créer un raccourci sur le Bureau avec l'icône AdminTools
   - ✅ Enregistrer un fichier journal dans `%TEMP%\AdminTools-Install.log`

4. **Vérifier l'installation**
   
   À la fin, vous devriez voir :
   ```
   [OK] PowerShell 7 est installé (version 7.x.x)
   [OK] Configuration du type de fichier .ps1 terminée
   [OK] Raccourci créé sur le Bureau : AdminTools
   
   Installation terminee avec succes !
   Le raccourci "AdminTools" a ete cree sur votre Bureau.
   ```

---

## 🔧 Étape 3 : Installer les outils RSAT (Active Directory)

AdminTools nécessite le module Active Directory pour fonctionner.

1. **Ouvrir PowerShell 7 en tant qu'administrateur**
   ```powershell
   # Installer RSAT - Active Directory
   Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
   ```

2. **Patienter pendant l'installation** (~2-5 minutes selon la connexion)

3. **Vérifier l'installation**
   ```powershell
   Get-Module -ListAvailable ActiveDirectory
   ```
   
   Vous devriez voir :
   ```
   ModuleType Version    Name
   ---------- -------    ----
   Manifest   1.0.1.0    ActiveDirectory
   ```

---

## 🌐 Étape 4 : Configurer WinRM (PowerShell distant)

Pour utiliser la fonctionnalité "Session PowerShell", WinRM doit être activé.

1. **Activer WinRM sur le poste local**
   ```powershell
   Enable-PSRemoting -Force
   ```

2. **Vérifier la configuration**
   ```powershell
   Test-WSMan
   ```
   
   Si la commande retourne des informations (version, ProductVendor...), c'est bon ✅

3. **Configurer le pare-feu** (si nécessaire)
   ```powershell
   Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -Enabled True
   ```

---

## 🎯 Étape 5 : Lancer AdminTools

### Première utilisation

1. **Double-cliquer sur le raccourci "AdminTools"** sur le Bureau

2. **Accepter l'élévation de privilèges** (UAC - demande administrateur)

3. **L'interface graphique s'ouvre** 
   - Titre : `AdminTools - Version locale` ou `AdminTools - v1.0 - dev@xxxxxxx (2026-01-26)`
   - Zone de recherche pour les ordinateurs
   - Boutons d'action : Session PowerShell, MSRA, RDP, Gestion, C:, Mettre à jour, Quitter

### Test de fonctionnement

1. **Rechercher un ordinateur**
   - Taper le nom d'un ordinateur dans la zone de recherche (ex: "WIN00156")
   - Les résultats s'affichent en temps réel

2. **Tester une fonction**
   - Sélectionner un ordinateur dans la liste
   - Cliquer sur **"Session PowerShell"** pour ouvrir une session distante
   - Vérifier que Windows Terminal s'ouvre avec la session

---

## 🔄 Étape 6 : Configurer les mises à jour automatiques

AdminTools inclut un système de mise à jour intégré.

### Vérifier les mises à jour

1. Dans l'application, cliquer sur le bouton **"Mettre à jour"** (icône 🔄)

2. Le système vérifie automatiquement si une nouvelle version est disponible

3. Si des mises à jour existent :
   - Un changelog s'affiche avec les modifications
   - Cliquer sur **"Mettre à jour"** pour appliquer
   - L'application redémarre automatiquement

### Configuration Git pour les mises à jour

Pour recevoir les mises à jour, le dépôt doit être configuré :

```powershell
cd C:\tools\AdminTools
git remote -v
# Doit afficher : origin  https://github.com/Zweikow/AdminTools.git

# Configurer la branche de tracking
git branch --set-upstream-to=origin/dev dev
```

---

## 📌 Étape 7 : Configuration supplémentaire (optionnel)

### Épingler à la barre des tâches

1. Clic droit sur le raccourci Bureau "AdminTools"
2. Choisir **"Épingler à la barre des tâches"**

### Créer un raccourci clavier

1. Clic droit sur le raccourci Bureau "AdminTools" → Propriétés
2. Dans le champ **"Touche de raccourci"**, définir une combinaison (ex: `Ctrl+Alt+A`)
3. Cliquer **OK**

### Personnaliser le chemin d'installation

Si vous souhaitez installer ailleurs que `C:\tools\AdminTools` :

1. Modifier le fichier `src\Lancer-AdminToolsGUI.vbs` :
   ```vb
   scriptPath = "C:\VOTRE_CHEMIN\AdminTools\src\ScriptAdminGUI-WPF.ps1"
   ```

2. Modifier le raccourci Bureau :
   - Clic droit → Propriétés
   - Changer le champ **"Cible"** vers le nouveau chemin du `.vbs`

---

## ❓ Dépannage

### Problème : "L'exécution de scripts est désactivée"

**Solution :**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

### Problème : "PowerShell 7 n'est pas installé"

**Solution manuelle :**
```powershell
winget install Microsoft.PowerShell --silent
```

Ou télécharger depuis : https://github.com/PowerShell/PowerShell/releases

### Problème : "Module ActiveDirectory introuvable"

**Solution :**
```powershell
# Vérifier si RSAT est installé
Get-WindowsCapability -Online -Name "Rsat.ActiveDirectory*"

# Si State = NotPresent, installer :
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

### Problème : "Impossible de se connecter au poste distant"

**Causes possibles :**
1. WinRM désactivé sur la machine distante
2. Pare-feu bloquant le port 5985
3. Droits administrateurs insuffisants

**Solution :**
```powershell
# Sur la machine distante, exécuter :
Enable-PSRemoting -Force
winrm quickconfig
```

### Problème : "La fenêtre PowerShell reste visible"

**Solution :** 
- Vérifier que vous utilisez bien le raccourci créé par le script d'installation
- Le raccourci doit pointer vers `Lancer-AdminToolsGUI.vbs` (pas directement vers le `.ps1`)

### Problème : "Git n'est pas reconnu"

**Solution :**
1. Installer Git depuis : https://git-scm.com/downloads
2. Redémarrer PowerShell
3. Vérifier : `git --version`

### Consulter les logs

Fichier journal d'installation :
```powershell
notepad $env:TEMP\AdminTools-Install.log
```

---

## 📞 Support

- **Documentation** : Voir [README.md](README.md)
- **Issues GitHub** : https://github.com/Zweikow/AdminTools/issues
- **Contact** : Contacter l'équipe d'administration système

---

## ✅ Checklist de vérification post-installation

Avant de déployer sur plusieurs postes, vérifier que :

- [ ] PowerShell 7 est installé (`pwsh --version`)
- [ ] Module ActiveDirectory disponible (`Get-Module -ListAvailable ActiveDirectory`)
- [ ] WinRM activé (`Test-WSMan`)
- [ ] Git installé (`git --version`)
- [ ] Raccourci Bureau créé
- [ ] Application lance sans erreur
- [ ] Recherche Active Directory fonctionne
- [ ] Session PowerShell distante fonctionne
- [ ] Bouton "Mettre à jour" détecte le dépôt Git
- [ ] Icône affichée correctement

---

## 🚀 Déploiement en masse (IT Admins)

Pour déployer sur plusieurs postes :

### Via GPO (Group Policy)

1. Créer un script de déploiement `.ps1` :
   ```powershell
   # Deploy-AdminTools.ps1
   New-Item -Path "C:\tools" -ItemType Directory -Force
   git clone https://github.com/Zweikow/AdminTools.git C:\tools\AdminTools
   cd C:\tools\AdminTools
   .\Install-Configure-AdminTools-Shortcut.ps1
   Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
   ```

2. Créer une GPO de démarrage qui exécute ce script

### Via Intune/SCCM

1. Créer un package d'application avec le script d'installation
2. Déployer sur le groupe de postes cibles
3. Configurer les prérequis (RSAT, WinRM)

### Via script distant

```powershell
$computers = Get-ADComputer -Filter * -SearchBase "OU=Workstations,DC=domain,DC=com"
foreach ($pc in $computers) {
    Invoke-Command -ComputerName $pc.Name -ScriptBlock {
        git clone https://github.com/Zweikow/AdminTools.git C:\tools\AdminTools
        cd C:\tools\AdminTools
        .\Install-Configure-AdminTools-Shortcut.ps1
    }
}
```

---

**Version du guide** : 1.0  
**Dernière mise à jour** : 26 janvier 2026
