# ScriptAdminCSharp (WPF)

Ce dossier contient une version C# WPF de l'outil d'administration distante.

## Fonctionnalités de base :
- Interface graphique moderne (WPF)
- Fenêtre principale avec boutons (Session PowerShell, Assistance MSRA, Profils utilisateurs, Session RDP, Gestion ordinateur, Partage C$)
- Squelette prêt à accueillir la logique d'administration
- Exemple de log dans un fichier texte

## Prérequis :
- .NET 6 ou supérieur (SDK)
- Visual Studio 2022 ou plus récent (ou VS Code avec extension C#)

## Compilation :
1. Ouvrir le dossier dans Visual Studio
2. Compiler le projet (F6 ou Ctrl+Maj+B)

## Exécution :
- Lancer l'exécutable généré dans `bin/Debug/net6.0-windows/`

## Personnalisation :
- Ajouter votre logique d'administration dans les handlers des boutons (voir `MainWindow.xaml.cs`) 