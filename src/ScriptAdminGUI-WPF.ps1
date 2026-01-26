# Vérifie si le script est lancé en admin, sinon relance en admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Chemin du dépôt Git (où se trouve le projet)
# Détecte automatiquement le chemin du repo en remontant depuis le script
$global:RepoPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path "$global:RepoPath\.git")) {
    # Fallback vers C:\tools si pas de .git trouvé
    $global:RepoPath = "C:\tools"
}

function Get-CurrentVersion {
    try {
        $gitPath = Get-Command git -ErrorAction SilentlyContinue
        if (-not $gitPath) { return "Version inconnue (Git non installé)" }
        
        Push-Location $global:RepoPath
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        $commitShort = git rev-parse --short HEAD 2>$null
        $commitDate = git log -1 --format=%cd --date=short 2>$null
        Pop-Location
        
        if ($commitShort) {
            return "v1.0 - $branch@$commitShort ($commitDate)"
        }
        return "Version locale"
    } catch {
        return "Version inconnue"
    }
}

function Test-UpdateAvailable {
    try {
        $gitPath = Get-Command git -ErrorAction SilentlyContinue
        if (-not $gitPath) { return $false }
        
        Push-Location $global:RepoPath
        
        # Fetch les dernières modifications
        git fetch origin 2>&1 | Out-Null
        
        # Compare local vs remote
        $localCommit = git rev-parse HEAD 2>$null
        $remoteCommit = git rev-parse '@{u}' 2>$null
        
        Pop-Location
        
        return ($localCommit -ne $remoteCommit)
    } catch {
        Pop-Location
        return $false
    }
}

function Get-UpdateChangelog {
    try {
        Push-Location $global:RepoPath
        
        # Récupère les commits entre local et remote
        $commits = git log HEAD..@{u} --pretty=format:"• %s (%an - %ar)" --max-count=10 2>$null
        
        Pop-Location
        
        if ($commits) {
            return $commits -join "`n"
        }
        return "Aucun détail disponible"
    } catch {
        Pop-Location
        return "Impossible de récupérer les changements"
    }
}

function Invoke-AutoUpdate {
    param([System.Windows.Window]$ParentWindow)
    
    try {
        # Vérifier que Git est installé
        $gitPath = Get-Command git -ErrorAction SilentlyContinue
        if (-not $gitPath) {
            [System.Windows.MessageBox]::Show(
                "Git n'est pas installé sur ce système.`n`nInstallez Git depuis : https://git-scm.com/",
                "Mise à jour impossible",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
            return
        }
        
        # Vérifier que le dossier est un repo Git
        if (-not (Test-Path "$global:RepoPath\.git")) {
            [System.Windows.MessageBox]::Show(
                "Le dossier $global:RepoPath n'est pas un dépôt Git valide.",
                "Mise à jour impossible",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
            return
        }
        
        # Vérifier les mises à jour disponibles
        if (-not (Test-UpdateAvailable)) {
            [System.Windows.MessageBox]::Show(
                "Vous utilisez déjà la dernière version d'AdminTools !",
                "Aucune mise à jour",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
            return
        }
        
        # Récupérer le changelog
        $changelog = Get-UpdateChangelog
        
        # Demander confirmation
        $message = "Une mise à jour est disponible !`n`n"
        $message += "Nouveautés :`n$changelog`n`n"
        $message += "Voulez-vous mettre à jour maintenant ?`n"
        $message += "(L'application redémarrera automatiquement)"
        
        $result = [System.Windows.MessageBox]::Show(
            $message,
            "Mise à jour disponible",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        
        if ($result -ne [System.Windows.MessageBoxResult]::Yes) {
            return
        }
        
        # Créer une sauvegarde
        $backupPath = "$global:RepoPath\.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        try {
            Write-Host "Création d'une sauvegarde dans $backupPath..."
            Copy-Item -Path "$global:RepoPath\src" -Destination $backupPath -Recurse -Force
        } catch {
            Write-Host "Avertissement : Impossible de créer la sauvegarde : $_"
        }
        
        # Effectuer la mise à jour
        Push-Location $global:RepoPath
        
        $pullOutput = git pull origin 2>&1
        $pullSuccess = $LASTEXITCODE -eq 0
        
        Pop-Location
        
        if ($pullSuccess) {
            [System.Windows.MessageBox]::Show(
                "Mise à jour effectuée avec succès !`n`nL'application va redémarrer.",
                "Mise à jour terminée",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
            
            # Fermer la fenêtre actuelle
            $ParentWindow.Close()
            
            # Redémarrer l'application
            Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
            
        } else {
            [System.Windows.MessageBox]::Show(
                "Erreur lors de la mise à jour :`n$pullOutput`n`nVeuillez vérifier votre connexion réseau ou faire la mise à jour manuellement.",
                "Erreur de mise à jour",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        }
        
    } catch {
        [System.Windows.MessageBox]::Show(
            "Erreur inattendue lors de la mise à jour :`n$_",
            "Erreur",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

function Find-ADComputer {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SearchString
    )
    try {
        if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) {
            Import-Module ActiveDirectory -ErrorAction Stop
        }
        if ([string]::IsNullOrWhiteSpace($SearchString)) {
            return @()
        }
        $filter = "(Name -like '*$SearchString*') -or (Description -like '*$SearchString*')"
        if ($SearchString -match '^[0-9]{1,3}(\.[0-9]{1,3}){0,3}$') {
            $filter = "$filter -or (IPv4Address -like '*$SearchString*')"
        }
        $computers = Get-ADComputer -Filter $filter -Properties Name, IPv4Address, Description
        $results = @()
        foreach ($c in $computers) {
            $results += [PSCustomObject]@{
                Nom = $c.Name
                IP = $c.IPv4Address
                Description = $c.Description
            }
        }
        return ,@($results)
    } catch {
        return @()
    }
}

# --- Fenêtre d'authentification WPF ---
# (SUPPRIMÉ : plus de fenêtre d'authentification ni de credential global)

$currentVersion = Get-CurrentVersion
$updateAvailable = Test-UpdateAvailable

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="AdminTools - $currentVersion" Height="640" Width="420" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="180"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <Grid Grid.Row="0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="170"/>
                <ColumnDefinition Width="200"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock Text="Nom d'ordinateur ou IP :" Grid.Column="0" VerticalAlignment="Center"/>
            <TextBox Name="txtHost" Grid.Column="1" Width="200" Height="22" HorizontalAlignment="Left"/>
        </Grid>
        <DataGrid Name="dataGridResults" Grid.Row="1" AutoGenerateColumns="False" Height="160" Margin="0,10,0,0">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Nom" Binding="{Binding Nom}" Width="*"/>
                <DataGridTextColumn Header="IP" Binding="{Binding IP}" Width="*"/>
                <DataGridTextColumn Header="Description" Binding="{Binding Description}" Width="*"/>
            </DataGrid.Columns>
        </DataGrid>
        <StackPanel Grid.Row="2" Margin="0,20,0,0" Orientation="Vertical" Width="380">
            <Button Name="btnPS" Content="Session PowerShell" Height="30" Margin="0,0,0,10"/>
            <Button Name="btnMSRA" Content="Assistance à distance (MSRA)" Height="30" Margin="0,0,0,10"/>
            <Button Name="btnRDP" Content="Session RDP" Height="30" Margin="0,0,0,10"/>
            <Button Name="btnGestion" Content="Gestion de l'ordinateur" Height="30" Margin="0,0,0,10"/>
            <Button Name="btnCShare" Content="Connexion au disque C: (admin)" Height="30" Margin="0,0,0,10"/>
        </StackPanel>
        <Grid Grid.Row="3">
            <Button Name="btnUpdate" Content="🔄 Mettre à jour" Height="30" HorizontalAlignment="Left" VerticalAlignment="Bottom" Margin="0,0,0,10" Width="140"/>
            <Button Name="btnQuit" Content="Quitter" Height="30" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,0,10" Width="100"/>
        </Grid>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$txtHost = $window.FindName('txtHost')
$dataGrid = $window.FindName('dataGridResults')
$btnQuit = $window.FindName('btnQuit')
$btnUpdate = $window.FindName('btnUpdate')
$btnPS = $window.FindName('btnPS')
$btnMSRA = $window.FindName('btnMSRA')
$btnRDP = $window.FindName('btnRDP')
$btnGestion = $window.FindName('btnGestion')
$btnCShare = $window.FindName('btnCShare')

# Colorer le bouton Mettre à jour si une MAJ est disponible
if ($updateAvailable) {
    $btnUpdate.Background = [System.Windows.Media.Brushes]::Orange
    $btnUpdate.Content = "🔄 Mettre à jour (nouveau !)"
}

$btnQuit.Add_Click({ $window.Close() })

$btnUpdate.Add_Click({
    Invoke-AutoUpdate -ParentWindow $window
})

$txtHost.Add_KeyUp({
    $search = $txtHost.Text.Trim()
    if (-not $search) {
        $dataGrid.ItemsSource = $null
        return
    }
    $results = Find-ADComputer -SearchString $search
    $dataGrid.ItemsSource = $null
    if ($results.Count -gt 0) {
        $dataGrid.ItemsSource = $results
    }
})

$txtHost.Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq 'Enter') {
        $btnPS.RaiseEvent([Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    }
})

$btnPS.Add_Click({
    $selected = $dataGrid.SelectedItem
    if (-not $selected) { return }
    $target = $selected.Nom

    Start-Process wt.exe -ArgumentList @(
        "powershell.exe",
        "-NoExit",
        "-Command",
        "Enter-PSSession -ComputerName $target"
    ) -Verb RunAs
})

$btnMSRA.Add_Click({
    $selected = $dataGrid.SelectedItem
    if (-not $selected) { return }
    $target = $selected.Nom

    Start-Process msra.exe -ArgumentList "/offerra $target"
})

$btnRDP.Add_Click({
    $selected = $dataGrid.SelectedItem
    if (-not $selected) { return }
    $target = $selected.Nom

    # Récupère le nom d'utilisateur courant et nettoie pour le nom de fichier
    $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name -replace '[\\/:*?"<>|]', '-'

    # Date et heure pour le nom du fichier
    $now = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"

    # Dossier de destination
    $destDir = 'C:\\temp\\RDP'
    if (-not (Test-Path $destDir)) {
        New-Item -Path $destDir -ItemType Directory | Out-Null
    }

    # Chemin du fichier temporaire
    $tempRdp = [System.IO.Path]::Combine($env:TEMP, 'MyConnection.rdp')
    # Chemin du fichier final
    $finalRdp = "$destDir\\RDP-$user-$now.rdp"

    # Génère le fichier RDP de base
    $rdpContent = "full address:s:$target`r`nusername:s:$user`r`n"
    Set-Content -Path $tempRdp -Value $rdpContent -Encoding ASCII

    # Déplace et renomme le fichier (en gérant les erreurs)
    try {
        Move-Item -Path $tempRdp -Destination $finalRdp -Force
    } catch {
        Write-Host "Erreur lors du déplacement du fichier RDP : $_"
        return
    }

    # Ouvre la connexion RDP avec le fichier généré
    Start-Process mstsc.exe -ArgumentList $finalRdp
})

$btnGestion.Add_Click({
    $selected = $dataGrid.SelectedItem
    if (-not $selected) { return }
    $target = $selected.Nom

    Start-Process compmgmt.msc -ArgumentList "/computer:\\$target" -Verb RunAs
})

$btnCShare.Add_Click({
    $selected = $dataGrid.SelectedItem
    if (-not $selected) { return }
    $target = $selected.Nom

    $share = "\\$target\C$"
    Start-Process explorer.exe $share -Verb RunAs
})

if (-not ($args -contains '-ProfileManager')) {
    # Afficher la fenêtre
    $null = $window.Show()
    
    # Vérification discrète des mises à jour au démarrage (en arrière-plan)
    $window.Dispatcher.InvokeAsync({
        Start-Sleep -Seconds 2  # Attendre que l'interface soit chargée
        
        if (Test-UpdateAvailable) {
            # Notification discrète
            $result = [System.Windows.MessageBox]::Show(
                "Une nouvelle version d'AdminTools est disponible !`n`nVoulez-vous voir les détails ?",
                "Mise à jour disponible",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Information
            )
            
            if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                Invoke-AutoUpdate -ParentWindow $window
            }
        }
    }.GetNewClosure()) | Out-Null
    
    # Attendre la fermeture de la fenêtre
    $window.ShowDialog() | Out-Null
}