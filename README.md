# AdminTools

## Présentation

**AdminTools** est un ensemble d’outils d’administration pour Windows permettant de faciliter la gestion à distance des postes de travail dans un environnement Active Directory. Il propose une interface graphique moderne (WPF) et une interface en ligne de commande (CLI).

---

## Fonctionnalités principales

- **Recherche Active Directory** : Trouver rapidement un ordinateur par nom, IP ou description.
- **Session PowerShell distante** : Ouvre une session PowerShell sur le poste sélectionné (via Windows Terminal, avec élévation UAC).
- **Assistance à distance (MSRA)** : Lance l’outil d’assistance à distance Microsoft pour aider un utilisateur.
- **Session RDP** : Génère un fichier RDP personnalisé, le déplace dans `C:\temp\RDP`, puis ouvre la connexion Bureau à distance.
- **Gestion de l’ordinateur** : Ouvre la MMC de gestion de l’ordinateur distant en mode administrateur.
- **Connexion au partage C$ (admin)** : Ouvre l’explorateur sur le partage C$ distant avec le compte `admin2`.
- **Recherche de mises à jour** : (optionnelle) Déclenche la recherche de mises à jour Windows sur le poste distant.
- **Filtrage en temps réel** : La recherche AD se fait automatiquement à chaque frappe dans la barre de recherche.

---

## Prérequis

- Windows 10/11
- PowerShell 5.1 ou supérieur
- Module PowerShell ActiveDirectory (RSAT)
- Accès administrateur sur les postes distants pour certaines fonctions
- Droit d’exécution à distance (WinRM activé pour PowerShell distant)
- Microsoft Remote Assistance (MSRA) installé
- Windows Terminal (`wt.exe`) pour la session PowerShell moderne

---

## Installation

1. **Cloner le dépôt**
   ```sh
   git clone https://github.com/Zweikow/AdminTools.git
   ```
2. **Installer les prérequis**
   - Activer les outils d’administration RSAT (Active Directory)
   - Vérifier que WinRM est activé sur les postes distants
   - Installer Windows Terminal (Microsoft Store)

---

## Utilisation

### Interface graphique (WPF)

1. Ouvrir une console PowerShell en tant qu’administrateur
2. Lancer le script GUI :
   ```powershell
   .\AdminToolsGUI\AdminToolsGUI-WPF\ScriptAdminGUI-WPF.ps1
   ```
3. Utiliser la barre de recherche pour trouver un poste (filtrage en temps réel)
4. Sélectionner un poste et utiliser les boutons pour lancer les actions souhaitées

### Interface CLI

1. Lancer le script CLI :
   ```powershell
   .\AdminToolsCLI\ScriptAdminCLI.ps1
   ```
2. Suivre les instructions dans le terminal

---

## Détails techniques

- **Recherche AD** : Utilise le module PowerShell ActiveDirectory pour interroger les ordinateurs.
- **Session PowerShell** : Ouvre Windows Terminal avec `Enter-PSSession` sur la machine cible.
- **RDP** : Génère un fichier `.rdp` personnalisé, le déplace dans `C:\temp\RDP` et l’ouvre avec `mstsc.exe`.
- **C$** : Utilise `runas` pour ouvrir l’explorateur avec le compte `admin2`.
- **Gestion de l’ordinateur** : Lance `compmgmt.msc` en mode administrateur sur la cible.
- **Assistance à distance** : Utilise `msra.exe /offerra`.

---

## Limitations & Conseils

- Certaines fonctions nécessitent des droits administrateur sur la machine distante.
- Pour la session PowerShell distante, WinRM doit être activé sur la cible.
- Le partage C$ doit être accessible et le compte `admin2` doit avoir les droits nécessaires.
- Pour la recherche de mises à jour, privilégier l’utilisation de `UsoClient.exe` ou du module PSWindowsUpdate selon le contexte.

---

## Auteurs

- Projet développé par [Zweikow](https://github.com/Zweikow) et contributeurs.

---

## Licence

Ce projet est distribué sous licence MIT. 