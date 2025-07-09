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
            <Button Name="btnSearch" Content="Recherche" Grid.Column="2" Width="70" Height="22" Margin="10,0,0,0"/>
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
            <Button Name="btnProfile" Content="Manage profil utilisateur" Height="30" Margin="0,0,0,10"/>
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
$btnSearch = $window.FindName('btnSearch')
$dataGrid = $window.FindName('dataGridResults')
$btnQuit = $window.FindName('btnQuit')

$btnQuit.Add_Click({ $window.Close() })

$btnSearch.Add_Click({
    $search = $txtHost.Text.Trim()
    if (-not $search) { return }
    $results = Find-ADComputer -SearchString $search
    $dataGrid.ItemsSource = $null
    if ($results.Count -gt 0) {
        $dataGrid.ItemsSource = $results
    }
})

$window.ShowDialog() | Out-Null 