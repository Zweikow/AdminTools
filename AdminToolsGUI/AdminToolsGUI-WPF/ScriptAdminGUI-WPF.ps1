Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Auto-élévation UAC au démarrage (une seule invite)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $psExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $psExe) { $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source }
    if ($psExe) {
        Start-Process -FilePath $psExe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"") -Verb RunAs | Out-Null
        exit
    } else {
        [System.Windows.MessageBox]::Show("Impossible de trouver PowerShell pour effectuer l'élévation.", "AdminTools", 'OK', 'Error') | Out-Null
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

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="AdminTools - Connexion à distance" Height="640" Width="420" WindowStartupLocation="CenterScreen">
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
        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,0,10">
            <Button Name="btnUpdate" Height="30" Margin="0,0,10,0" ToolTip="Mettre à jour l'application">
                <StackPanel Orientation="Horizontal">
                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE72C;" VerticalAlignment="Center"/>
                    <TextBlock Text=" Mettre à jour" VerticalAlignment="Center"/>
                </StackPanel>
            </Button>
            <Button Name="btnQuit" Content="Quitter" Height="30"/>
        </StackPanel>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$txtHost = $window.FindName('txtHost')
$dataGrid = $window.FindName('dataGridResults')
$btnQuit = $window.FindName('btnQuit')
$btnPS = $window.FindName('btnPS')
$btnMSRA = $window.FindName('btnMSRA')
$btnRDP = $window.FindName('btnRDP')
$btnGestion = $window.FindName('btnGestion')
$btnCShare = $window.FindName('btnCShare')
$btnUpdate = $window.FindName('btnUpdate')

$btnQuit.Add_Click({ $window.Close() })

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
    )
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

    # Génère le fichier RDP de base (pas de ligne vide au début, retours à la ligne Windows)
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

    Start-Process compmgmt.msc -ArgumentList "/computer:\\$target"
})

$btnCShare.Add_Click({
    $selected = $dataGrid.SelectedItem
    if (-not $selected) { return }
    $target = $selected.Nom

    $share = "\\\\$target\C`$"
    Start-Process explorer.exe $share
})

$btnUpdate.Add_Click({
    # Désactive le bouton et affiche un curseur d'attente
    $btnUpdate.IsEnabled = $false
    [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait

    try {
        # Détermine la racine du dépôt (deux niveaux au-dessus du dossier du script)
        $repoRoot = (Split-Path $PSScriptRoot -Parent | Split-Path -Parent)
        $gitDir = Join-Path $repoRoot '.git'
        if (-not (Test-Path $gitDir)) {
            [System.Windows.MessageBox]::Show("Dépôt Git introuvable au chemin : $repoRoot", "Mise à jour", 'OK', 'Error') | Out-Null
            return
        }

        # Vérifie la disponibilité de git
        $gitCmd = (Get-Command git -ErrorAction SilentlyContinue)
        if (-not $gitCmd) {
            [System.Windows.MessageBox]::Show("L'outil 'git' n'est pas disponible dans le PATH.", "Mise à jour", 'OK', 'Error') | Out-Null
            return
        }

        $ok = $true
        $errors = @()
        $didStash = $false

        # Si l'arbre de travail contient des modifications locales, proposer un stash temporaire
        $dirty = (& git -C $repoRoot status --porcelain 2>$null)
        if ($dirty) {
            $choice = [System.Windows.MessageBox]::Show(
                "Des modifications locales non commit ont été détectées. Voulez-vous les mettre de côté (stash) temporairement pour effectuer la mise à jour ?",
                "Mise à jour", 'YesNo', 'Question'
            )
            if ($choice -ne 'Yes') {
                return
            }
            & git -C $repoRoot stash push -u -m "auto-stash AdminTools updater $(Get-Date -Format yyyy-MM-dd-HH-mm-ss)" 2>&1 | ForEach-Object { $errors += $_ }
            if ($LASTEXITCODE -ne 0) {
                $ok = $false
            } else {
                $didStash = $true
            }
        }

        # Récupère les dernières modifications
        if ($ok) {
            & git -C $repoRoot fetch --all --tags 2>&1 | ForEach-Object { $errors += $_ }
            if ($LASTEXITCODE -ne 0) { $ok = $false }
        }

        if ($ok) {
            & git -C $repoRoot pull --ff-only 2>&1 | ForEach-Object { $errors += $_ }
            if ($LASTEXITCODE -ne 0) { $ok = $false }
        }

        # Si nous avions stashé, tenter un pop après mise à jour
        $popInfo = $null
        if ($ok -and $didStash) {
            $popOut = & git -C $repoRoot stash pop 2>&1
            $errors += $popOut
            $popInfo = ($popOut -join "`n")
        }

        if (-not $ok) {
            $msg = "La mise à jour a échoué. Détails :`n" + ($errors -join "`n")
            [System.Windows.MessageBox]::Show($msg, "Mise à jour", 'OK', 'Error') | Out-Null
            return
        }

        $successMsg = "Mise à jour terminée avec succès."
        if ($didStash) {
            if ($popInfo -and ($popInfo -match 'CONFLICT' -or $popInfo -match 'Merge conflict')) {
                $successMsg += "`nAttention : des conflits sont survenus lors du 'stash pop'. Résolvez-les manuellement."
            } elseif ($popInfo) {
                $successMsg += "`nVos modifications locales ont été restaurées (stash pop)."
            }
        }

        $res = [System.Windows.MessageBox]::Show($successMsg + "`nRedémarrer l'application maintenant ?", "Mise à jour", 'YesNo', 'Information')
        if ($res -eq 'Yes') {
            # Détermine l'exécutable PowerShell disponible (pwsh de préférence)
            $psExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
            if (-not $psExe) { $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source }
            if ($psExe) {
                Start-Process -FilePath $psExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"") | Out-Null
                $window.Close()
            } else {
                [System.Windows.MessageBox]::Show("Impossible de trouver PowerShell pour relancer l'application.", "Mise à jour", 'OK', 'Warning') | Out-Null
            }
        }
    } catch {
        [System.Windows.MessageBox]::Show("Erreur inattendue : $_", "Mise à jour", 'OK', 'Error') | Out-Null
    } finally {
        # Restaure l'UI
        [System.Windows.Input.Mouse]::OverrideCursor = $null
        $btnUpdate.IsEnabled = $true
    }
})

$window.ShowDialog() | Out-Null