Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

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
        Title="AdminTools - Connexion à distance (WPF)" Height="640" Width="420" WindowStartupLocation="CenterScreen">
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
            <Button Name="btnCShare" Content="Connexion au partage C$ (admin)" Height="30" Margin="0,0,0,10"/>
            <Button Name="btnUpdate" Content="Lancer la recherche de mises à jour" Height="30" Margin="0,0,0,10"/>
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

    Start-Process compmgmt.msc -ArgumentList "/computer:\\$target" -Verb RunAs
})

$btnCShare.Add_Click({
    $selected = $dataGrid.SelectedItem
    if (-not $selected) { return }
    $target = $selected.Nom

    $user = "admin2"
    $cmd = "explorer.exe \\$target\C$"
    Start-Process runas.exe -ArgumentList "/user:$user", $cmd
})

$window.ShowDialog() | Out-Null