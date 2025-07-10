# AdminTools

## Présentation

**AdminTools** est un outil d’administration pour Windows permettant de faciliter la gestion à distance des postes de travail dans un environnement Active Directory. Il propose une interface graphique moderne (WPF) et une interface en ligne de commande (CLI).

---

## Résumé du développement

1. **Départ du projet**  
   - Tu travailles sur un outil d’administration Windows (AdminTools) avec une interface graphique WPF en PowerShell.
   - Tu as déjà intégré la recherche Active Directory (AD) et souhaites ajouter les autres fonctionnalités une à une.

2. **Ajout des fonctionnalités principales**  
   - **Session PowerShell distante** :  
     - Intégrée via un bouton qui ouvre une session distante avec `Enter-PSSession` dans Windows Terminal (`wt.exe`), avec ou sans demande d’identifiants selon le contexte.
   - **Assistance à distance (MSRA)** :  
     - Ajout d’un bouton qui lance `msra.exe /offerra <nom_machine>` pour l’assistance à distance.
   - **Session RDP** :  
     - Génération d’un fichier `.rdp` dans `%TEMP%`, déplacement dans `C:\temp\RDP`, renommage dynamique, puis ouverture avec `mstsc.exe`.
     - Correction du nom de fichier pour éviter les caractères interdits.
   - **Gestion de l’ordinateur** :  
     - Bouton qui lance `compmgmt.msc /computer:\\<nom_machine>` en mode administrateur.
   - **Connexion au partage C$ (admin)** :  
     - Plusieurs essais :  
       - D’abord avec `runas` (problèmes de fermeture immédiate ou de prompt).
       - Puis avec `net use` pour mapper le partage avec mot de passe, puis ouverture de l’explorateur.
       - Finalement, version simple : ouverture directe de `\\<nom_machine>\C$` dans l’explorateur, laissant Windows gérer l’authentification.
   - **Suppression de fonctionnalités** :  
     - Suppression de « Manage profil utilisateur », « Lancer la recherche de mises à jour », « Envoyer un message », et « Réglages » pour simplifier l’outil.

3. **Améliorations UX/UI**  
   - Recherche AD en temps réel (filtrage à chaque frappe dans la barre de recherche).
   - Suppression du bouton « Recherche » devenu inutile.
   - Positionnement du bouton « Quitter » en bas à droite, suppression des doublons.
   - Correction des erreurs de XAML (noms de boutons dupliqués).

4. **Gestion du compte admin par défaut**  
   - Intégration d’une fenêtre « Réglages » pour saisir et stocker (chiffré) le compte admin par défaut dans `%APPDATA%`.
   - Utilisation automatique de ce compte pour les actions distantes (PowerShell, MSG, etc.).
   - Finalement, suppression de cette fonctionnalité pour revenir à une gestion plus simple et universelle.

5. **Compatibilité multi-utilisateurs**  
   - Explication que chaque technicien peut configurer son propre compte admin (quand la fonctionnalité était présente), stockage sécurisé par profil Windows.

6. **Documentation et diffusion**  
   - Création et mise à jour d’un README.md détaillé :  
     - Présentation, fonctionnalités, prérequis, installation, utilisation, limitations, auteurs, licence.
     - Ajout d’une section sur la création d’un raccourci VBS pour lancer l’application sans terminal, avec icône personnalisée, et épinglable à la barre des tâches.
   - Explications étape par étape pour l’installation complète, la personnalisation du raccourci, et l’épinglage à la barre des tâches.

7. **Gestion des erreurs et conseils**  
   - Aide sur les erreurs PowerShell/VSCode (problèmes de pipe, redémarrage de l’extension).
   - Correction d’un bug lors du chargement du mot de passe admin (fichier vide ou corrompu).
   - Conseils sur les limitations de Windows concernant `runas` et l’ouverture d’explorateur avec un autre compte.

8. **Gestion de versions et releases**  
   - Instructions pour créer un tag Git (`v1.0.1`), pousser les modifications, et générer une release note détaillée.

9. **Personnalisation de l’icône**  
   - Explications pour utiliser un fichier `.ico` personnalisé pour le raccourci VBS.

10. **Résultat final**  
    - Application AdminTools avec interface graphique WPF, boutons pour toutes les actions d’administration courantes, recherche AD en temps réel, et lancement via un raccourci VBS personnalisé sans terminal.

En résumé, tu as construit, étape par étape, un outil d’administration graphique moderne, ergonomique, documenté, et prêt à être partagé et utilisé par toute ton équipe, avec une expérience utilisateur professionnelle.

---

## Fonctionnalités principales

- **Recherche Active Directory** : Trouver rapidement un ordinateur par nom, IP ou description (filtrage en temps réel).
- **Session PowerShell distante** : Ouvre une session PowerShell sur le poste sélectionné (via Windows Terminal, avec élévation UAC).
- **Assistance à distance (MSRA)** : Lance l’outil d’assistance à distance Microsoft pour aider un utilisateur.
- **Session RDP** : Génère un fichier RDP personnalisé, le déplace dans `C:\temp\RDP`, puis ouvre la connexion Bureau à distance.
- **Gestion de l’ordinateur** : Ouvre la MMC de gestion de l’ordinateur distant en mode administrateur.
- **Connexion au disque C: (admin)** : Ouvre l’explorateur sur le partage C$ distant (`\\nom_machine\C$`).
- **Interface graphique moderne (WPF)** : Utilisation simple et intuitive, adaptée à l’administration quotidienne.

---

## Prérequis

- Windows 10/11
- PowerShell 7 (pwsh.exe)
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

3. **(Optionnel mais recommandé) Créer un raccourci pour lancer l’application sans terminal**
   - Place le fichier `Lancer-AdminToolsGUI.vbs` fourni à la racine du projet.
   - Crée un raccourci vers ce fichier VBS (clic droit > Créer un raccourci).
   - Clique droit sur le raccourci > **Propriétés** > **Changer d’icône...** et sélectionne ton fichier `.ico` personnalisé.
   - Place le raccourci où tu veux (bureau, menu démarrer, etc.) et épingle-le à la barre des tâches si besoin.
   - Double-clique sur le raccourci pour lancer l’application sans terminal en arrière-plan.

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

## Limitations & Conseils

- Certaines fonctions nécessitent des droits administrateur sur la machine distante.
- Pour la session PowerShell distante, WinRM doit être activé sur la cible.
- Le partage C$ doit être accessible et l’utilisateur doit avoir les droits nécessaires.
- L’authentification sur le partage C$ se fait via la fenêtre Windows standard si besoin.

---

## Auteurs

- Projet développé par [Zweikow](https://github.com/Zweikow) et contributeurs.

---

## Licence

Ce projet est distribué sous licence MIT.