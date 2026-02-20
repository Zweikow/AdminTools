# Masque la fenêtre de console PowerShell
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0) | Out-Null

# Vérifie si le script est lancé en admin, sinon relance en admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName Microsoft.VisualBasic

# --- DÉFINITION DES TYPES ---
if (-not ("AdminTools.ComputerItem" -as [type])) {
    Add-Type -TypeDefinition @"
    using System;
    using System.ComponentModel;
    namespace AdminTools {
        public class ComputerItem : INotifyPropertyChanged {
            public event PropertyChangedEventHandler PropertyChanged;
            private string _nom; public string Nom { get { return _nom; } set { _nom = value; OnPropertyChanged("Nom"); } }
            private string _ip; public string IP { get { return _ip; } set { _ip = value; OnPropertyChanged("IP"); } }
            private string _os; public string OS { get { return _os; } set { _os = value; OnPropertyChanged("OS"); } }
            private string _description; public string Description { get { return _description; } set { _description = value; OnPropertyChanged("Description"); } }
            private string _statusColor = "#4CAF50"; public string StatusColor { get { return _statusColor; } set { _statusColor = value; OnPropertyChanged("StatusColor"); } }
            protected void OnPropertyChanged(string name) {
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
            }
        }
    }
"@
}

# --- VARIABLES GLOBALES ET CHEMINS ---
$global:RepoPath = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path "$global:RepoPath\.git")) {
    $parent = Split-Path $global:RepoPath -Parent
    if (Test-Path "$parent\.git") { $global:RepoPath = $parent } else { $global:RepoPath = "C:\tools" }
}

$global:ConfigDir = "C:\tools\AdminTools"
if (-not (Test-Path $global:ConfigDir)) { New-Item -Path $global:ConfigDir -ItemType Directory -Force | Out-Null }
$global:HistoryFile = "$global:ConfigDir\history.json"
$global:SettingsFile = "$global:ConfigDir\settings.json"
$global:RepoUrl = "https://raw.githubusercontent.com/Zweikow/AdminTools/main"

# --- FONCTIONS DE PARAMÈTRES ---
function Get-Settings {
    if (Test-Path $global:SettingsFile) {
        try { return (Get-Content $global:SettingsFile -Raw | ConvertFrom-Json) } catch {}
    }
    return [PSCustomObject]@{ Theme = "Dark"; SearchBase = "" }
}

function Save-Settings {
    param($Settings)
    $Settings | ConvertTo-Json | Set-Content $global:SettingsFile
}

# --- FONCTIONS D'HISTORIQUE ---
function Get-History {
    if (Test-Path $global:HistoryFile) {
        try { return @(Get-Content $global:HistoryFile -Raw | ConvertFrom-Json) } catch { return @() }
    }
    return @()
}

function Add-ToHistory {
    param([string]$ComputerName)
    $history = Get-History
    $history = @($history | Where-Object { $_ -ne $ComputerName })
    $history = @($ComputerName) + $history
    if ($history.Count -gt 7) { $history = $history[0..6] }
    $history | ConvertTo-Json | Set-Content $global:HistoryFile
    Update-HistoryUI
}

function Update-HistoryUI {
    $pnlRecentConnections.Children.Clear()
    $history = Get-History
    foreach ($comp in $history) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = "🖥  $comp"
        $btn.Style = $window.FindResource("ModernButton")
        $btn.Background = [System.Windows.Media.Brushes]::Transparent
        $btn.BorderThickness = 0
        $btn.Margin = "0,0,0,2"
        $btn.Add_Click({
            $txtHost.Text = $comp
            $txtHost.RaiseEvent([System.Windows.Input.KeyEventArgs]::new(
                [System.Windows.Input.Keyboard]::PrimaryDevice,
                [System.Windows.PresentationSource]::FromVisual($txtHost),
                0,
                [System.Windows.Input.Key]::Enter
            ))
        }.GetNewClosure())
        $pnlRecentConnections.Children.Add($btn) | Out-Null
    }
}

# --- FONCTIONS DE MISE À JOUR ---
function Get-RemoteVersion {
    try {
        $versionStr = Invoke-RestMethod -Uri "$global:RepoUrl/version.txt" -UseBasicParsing -ErrorAction Stop
        return $versionStr.Trim()
    } catch { return $null }
}

function Get-LocalVersion {
    $versionFile = "$global:RepoPath\version.txt"
    if (Test-Path $versionFile) { return (Get-Content $versionFile).Trim() }
    return "1.0.0"
}

function Test-UpdateAvailable {
    $remote = Get-RemoteVersion
    $local = Get-LocalVersion
    return ($remote -and $remote -ne $local)
}

function Invoke-AutoUpdate {
    param([System.Windows.Window]$ParentWindow)
    try {
        $remoteVersion = Get-RemoteVersion
        if (-not $remoteVersion) {
            [System.Windows.MessageBox]::Show("Impossible de vérifier la version en ligne.", "Erreur", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }
        $localVersion = Get-LocalVersion
        if ($remoteVersion -eq $localVersion) {
            [System.Windows.MessageBox]::Show("Vous utilisez déjà la dernière version ($localVersion).", "À jour", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            return
        }
        $result = [System.Windows.MessageBox]::Show("Une nouvelle version ($remoteVersion) est disponible. Voulez-vous mettre à jour ?", "Mise à jour", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        if ($result -ne [System.Windows.MessageBoxResult]::Yes) { return }
        
        $newScriptUrl = "$global:RepoUrl/src/ScriptAdminGUI-WPF.ps1"
        $tempScript = "$env:TEMP\ScriptAdminGUI-WPF_new.ps1"
        Invoke-WebRequest -Uri $newScriptUrl -OutFile $tempScript -UseBasicParsing
        
        $tempVersion = "$env:TEMP\version.txt"
        Invoke-WebRequest -Uri "$global:RepoUrl/version.txt" -OutFile $tempVersion -UseBasicParsing
        
        $updaterScript = "$env:TEMP\updater.ps1"
        $currentScriptPath = $PSCommandPath
        $currentVersionPath = "$global:RepoPath\version.txt"
        
        $updaterCode = @"
Start-Sleep -Seconds 2
Copy-Item -Path '$tempScript' -Destination '$currentScriptPath' -Force
Copy-Item -Path '$tempVersion' -Destination '$currentVersionPath' -Force
Start-Process -FilePath 'pwsh.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "$currentScriptPath"' -Verb RunAs
"@
        Set-Content -Path $updaterScript -Value $updaterCode
        Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$updaterScript`""
        $ParentWindow.Close()
        exit
    } catch {
        [System.Windows.MessageBox]::Show("Erreur lors de la mise à jour : $_", "Erreur", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
}

# --- FONCTIONS MÉTIER ---
function Find-ADComputer {
    param([Parameter(Mandatory=$true)][string]$SearchString)
    try {
        if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) { Import-Module ActiveDirectory -ErrorAction Stop }
        if ([string]::IsNullOrWhiteSpace($SearchString)) { return @() }
        
        $filter = "(Name -like '*$SearchString*') -or (Description -like '*$SearchString*')"
        if ($SearchString -match '^[0-9]{1,3}(\.[0-9]{1,3}){0,3}$') {
            $filter = "$filter -or (IPv4Address -like '*$SearchString*')"
        }
        
        $settings = Get-Settings
        $searchBaseParam = @{}
        if (-not [string]::IsNullOrWhiteSpace($settings.SearchBase)) {
            $searchBaseParam['SearchBase'] = $settings.SearchBase
        }
        
        $computers = Get-ADComputer -Filter $filter -Properties Name, IPv4Address, Description, OperatingSystem @searchBaseParam
        $results = @()
        foreach ($c in $computers) {
            $item = New-Object AdminTools.ComputerItem
            $item.Nom = $c.Name
            $item.IP = $c.IPv4Address
            $item.OS = $c.OperatingSystem
            $item.Description = $c.Description
            $results += $item
        }
        return $results
    } catch { return @() }
}

$currentVersion = Get-LocalVersion
$updateAvailable = Test-UpdateAvailable

# --- INTERFACE UTILISATEUR (XAML) ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AdminTools - v$currentVersion" Height="720" Width="1150" 
        WindowStartupLocation="CenterScreen" Background="#181818" Foreground="#E0E0E0"
        FontFamily="Segoe UI Variable, Segoe UI, Arial">
    <Window.Resources>
        <!-- Button Style -->
        <Style TargetType="Button" x:Key="ModernButton">
            <Setter Property="Background" Value="#2D2D2D"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#3D3D3D"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#3D3D3D"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#4D4D4D"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.5"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- TextBox Style -->
        <Style TargetType="TextBox" x:Key="ModernTextBox">
            <Setter Property="Background" Value="#202020"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#333333"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,10"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="CaretBrush" Value="White"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="6">
                            <Grid>
                                <ScrollViewer x:Name="PART_ContentHost" Margin="0"/>
                                <TextBlock x:Name="PlaceholderText" Text="Search AD Computers (Name, IP, Description)" 
                                           Foreground="#888888" Padding="{TemplateBinding Padding}" 
                                           IsHitTestVisible="False" Visibility="Collapsed" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="Text" Value="">
                                <Setter TargetName="PlaceholderText" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger Property="IsFocused" Value="True">
                                <Setter Property="BorderBrush" Value="#4CC2FF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- DataGrid Style -->
        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderBrush" Value="#333333"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="RowBackground" Value="Transparent"/>
            <Setter Property="AlternatingRowBackground" Value="#1E1E1E"/>
            <Setter Property="HeadersVisibility" Value="Column"/>
            <Setter Property="GridLinesVisibility" Value="None"/>
            <Setter Property="Foreground" Value="#E0E0E0"/>
            <Setter Property="RowHeight" Value="35"/>
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="#181818"/>
            <Setter Property="Foreground" Value="#A0A0A0"/>
            <Setter Property="Padding" Value="12,10"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="BorderThickness" Value="0,0,0,1"/>
            <Setter Property="BorderBrush" Value="#333333"/>
        </Style>
        <Style TargetType="DataGridRow">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Foreground" Value="#E0E0E0"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#2C3E50"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#2A2A2A"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="DataGridCell">
            <Setter Property="Padding" Value="12,0"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Foreground" Value="{Binding Foreground, RelativeSource={RelativeSource AncestorType=DataGridRow}}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="DataGridCell">
                        <Border Background="Transparent" Padding="{TemplateBinding Padding}">
                            <ContentPresenter VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="240"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="280"/>
        </Grid.ColumnDefinitions>

        <!-- Sidebar -->
        <Border Grid.Column="0" Background="#141414" BorderBrush="#252525" BorderThickness="0,0,1,0">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                
                <StackPanel Grid.Row="0" Margin="15,20,15,10">
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,30">
                        <TextBlock Text="A" Foreground="#4CC2FF" FontSize="20" FontWeight="Bold" Margin="0,0,10,0"/>
                        <TextBlock Text="AdminTools" FontSize="18" FontWeight="SemiBold" Foreground="White" VerticalAlignment="Center"/>
                    </StackPanel>
                    
                    <Button Content="💻  Computers" Style="{StaticResource ModernButton}" Background="#2D3D4D" BorderBrush="#4CC2FF" Margin="0,0,0,8"/>
                    <Button Content="👤  Users (disabled)" Style="{StaticResource ModernButton}" Foreground="#666666" Background="Transparent" BorderThickness="0" IsEnabled="False" Margin="0,0,0,8"/>
                    <Button Name="btnSettings" Content="⚙  Settings" Style="{StaticResource ModernButton}" Background="Transparent" BorderThickness="0" Margin="0,0,0,25"/>
                    
                    <TextBlock Text="Recent Connections" Foreground="#888888" FontWeight="SemiBold" Margin="5,10,0,15"/>
                    <StackPanel Name="pnlRecentConnections">
                        <!-- Dynamically populated -->
                    </StackPanel>
                </StackPanel>
                
                <StackPanel Grid.Row="2" Margin="20,15" Orientation="Horizontal">
                    <TextBlock Text="Connection status:" Foreground="#888888" VerticalAlignment="Center" Margin="0,0,10,0"/>
                    <Ellipse Width="10" Height="10" Fill="#4CAF50" Margin="0,0,15,0"/>
                    <TextBlock Text="Current user: $env:USERNAME" Foreground="#888888" VerticalAlignment="Center"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Main Content -->
        <Grid Grid.Column="1" Margin="25">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <!-- Search Bar -->
            <TextBox Name="txtHost" Grid.Row="0" Style="{StaticResource ModernTextBox}" Margin="0,0,0,20"/>
            
            <!-- DataGrid -->
            <Border Grid.Row="1" Background="#1C1C1C" BorderBrush="#252525" BorderThickness="1" CornerRadius="8" ClipToBounds="True">
                <DataGrid Name="dataGridResults" AutoGenerateColumns="False" IsReadOnly="True" SelectionMode="Single" BorderThickness="0">
                    <DataGrid.Columns>
                        <DataGridTemplateColumn Header="Status" Width="60">
                            <DataGridTemplateColumn.CellTemplate>
                                <DataTemplate>
                                    <Ellipse Width="10" Height="10" Fill="{Binding StatusColor}" HorizontalAlignment="Center"/>
                                </DataTemplate>
                            </DataGridTemplateColumn.CellTemplate>
                        </DataGridTemplateColumn>
                        <DataGridTextColumn Header="Computer Name" Binding="{Binding Nom}" Width="2*"/>
                        <DataGridTextColumn Header="IP Address" Binding="{Binding IP}" Width="1.5*"/>
                        <DataGridTextColumn Header="Operating System" Binding="{Binding OS}" Width="2*"/>
                        <DataGridTextColumn Header="Description" Binding="{Binding Description}" Width="2*"/>
                    </DataGrid.Columns>
                </DataGrid>
            </Border>
        </Grid>

        <!-- Actions Panel -->
        <Border Grid.Column="2" Background="#181818" BorderBrush="#252525" BorderThickness="1,0,0,0" Padding="25">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                
                <StackPanel Grid.Row="0">
                    <TextBlock Text="Actions" FontSize="16" FontWeight="SemiBold" Foreground="White" Margin="0,0,0,20"/>
                    
                    <Border Background="#202020" CornerRadius="6" Padding="10" Margin="0,0,0,20">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="💻" Margin="0,0,10,0"/>
                            <TextBlock Name="txtSelectedComputer" Text="Sélectionnez un PC" Foreground="#4CC2FF" FontWeight="SemiBold"/>
                        </StackPanel>
                    </Border>

                    <Button Name="btnPS" Content="&gt;_  PowerShell Session (WT)" Style="{StaticResource ModernButton}" Height="45" Margin="0,0,0,12"/>
                    <Button Name="btnRDP" Content="🖥  Remote Desktop (RDP)" Style="{StaticResource ModernButton}" Height="45" Margin="0,0,0,12"/>
                    <Button Name="btnMSRA" Content="🤝  MSRA Assistance" Style="{StaticResource ModernButton}" Height="45" Margin="0,0,0,12"/>
                    <Button Name="btnGestion" Content="⚙  Computer Management" Style="{StaticResource ModernButton}" Height="45" Margin="0,0,0,12"/>
                    <Button Name="btnCShare" Content="📁  Open C$ Share" Style="{StaticResource ModernButton}" Height="45" Margin="0,0,0,12"/>
                    <Button Name="btnWOL" Content="⚡  Wake On LAN" Style="{StaticResource ModernButton}" Height="45" Margin="0,0,0,12"/>
                    <Button Name="btnReboot" Content="🔄  Reboot Computer" Style="{StaticResource ModernButton}" Height="45" Margin="0,0,0,12"/>
                </StackPanel>
                
                <StackPanel Grid.Row="2">
                    <Button Name="btnUpdate" Content="🔄  Mettre à jour" Style="{StaticResource ModernButton}" Height="40" Margin="0,0,0,10"/>
                    <Button Name="btnQuit" Content="Quitter" Style="{StaticResource ModernButton}" Height="40" Background="#3D2020" BorderBrush="#5C2D2D" Foreground="#FF8888"/>
                </StackPanel>
            </Grid>
        </Border>
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
$btnWOL = $window.FindName('btnWOL')
$btnReboot = $window.FindName('btnReboot')
$btnSettings = $window.FindName('btnSettings')
$txtSelectedComputer = $window.FindName('txtSelectedComputer')
$global:pnlRecentConnections = $window.FindName('pnlRecentConnections')

# Initialisation UI
Update-HistoryUI

if ($updateAvailable) {
    $btnUpdate.Background = [System.Windows.Media.Brushes]::Orange
    $btnUpdate.Content = "🔄 Mettre à jour (nouveau !)"
}

# --- ÉVÉNEMENTS ---
$btnQuit.Add_Click({ $window.Close() })

$btnUpdate.Add_Click({ Invoke-AutoUpdate -ParentWindow $window })

$btnSettings.Add_Click({
    $settings = Get-Settings
    [xml]$settingsXaml = @"
    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            Title="Settings" Height="250" Width="400" WindowStartupLocation="CenterOwner"
            Background="#181818" Foreground="#E0E0E0" FontFamily="Segoe UI Variable, Segoe UI, Arial"
            ResizeMode="NoResize">
        <Grid Margin="20">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <TextBlock Text="Theme:" Grid.Row="0" Margin="0,0,0,5"/>
            <ComboBox Name="cmbTheme" Grid.Row="0" HorizontalAlignment="Right" Width="150">
                <ComboBoxItem Content="Dark"/>
                <ComboBoxItem Content="Light"/>
            </ComboBox>
            
            <TextBlock Text="Search Base (OU):" Grid.Row="1" Margin="0,15,0,5"/>
            <TextBox Name="txtSearchBase" Grid.Row="1" HorizontalAlignment="Right" Width="250" Height="25" Margin="0,15,0,0"/>
            
            <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right">
                <Button Name="btnSave" Content="Save" Width="80" Margin="0,0,10,0" Background="#2D2D2D" Foreground="White"/>
                <Button Name="btnCancel" Content="Cancel" Width="80" Background="#2D2D2D" Foreground="White"/>
            </StackPanel>
        </Grid>
    </Window>
"@
    $reader = (New-Object System.Xml.XmlNodeReader $settingsXaml)
    $settingsWindow = [Windows.Markup.XamlReader]::Load($reader)
    $settingsWindow.Owner = $window
    
    $cmbTheme = $settingsWindow.FindName('cmbTheme')
    $txtSearchBase = $settingsWindow.FindName('txtSearchBase')
    $btnSave = $settingsWindow.FindName('btnSave')
    $btnCancel = $settingsWindow.FindName('btnCancel')
    
    $cmbTheme.Text = $settings.Theme
    $txtSearchBase.Text = $settings.SearchBase
    
    $btnCancel.Add_Click({ $settingsWindow.Close() })
    $btnSave.Add_Click({
        $settings.Theme = $cmbTheme.Text
        $settings.SearchBase = $txtSearchBase.Text
        Save-Settings $settings
        $settingsWindow.Close()
        [System.Windows.MessageBox]::Show("Settings saved. Some changes may require a restart.", "Settings", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    })
    
    $settingsWindow.ShowDialog() | Out-Null
})

$dataGrid.Add_SelectionChanged({
    $selected = $dataGrid.SelectedItem
    if ($selected) {
        $txtSelectedComputer.Text = $selected.Nom
    } else {
        $txtSelectedComputer.Text = "Sélectionnez un PC"
    }
})

$txtHost.Add_KeyUp({
    param($sender, $e)
    if ($e.Key -eq 'Enter') { return } # Géré par KeyDown
    
    $search = $txtHost.Text.Trim()
    if (-not $search) {
        $dataGrid.ItemsSource = $null
        return
    }
    $results = Find-ADComputer -SearchString $search
    $dataGrid.ItemsSource = $null
    if ($results.Count -gt 0) {
        $dataGrid.ItemsSource = $results
        
        # Ping asynchrone
        $runspacePool = [runspacefactory]::CreateRunspacePool(1, 5)
        $runspacePool.Open()
        $jobs = @()
        
        foreach ($item in $results) {
            if (-not [string]::IsNullOrWhiteSpace($item.IP)) {
                $pipeline = [powershell]::Create().AddScript({
                    param($ip)
                    return Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
                }).AddArgument($item.IP)
                $pipeline.RunspacePool = $runspacePool
                $jobs += [PSCustomObject]@{
                    Pipeline = $pipeline
                    AsyncResult = $pipeline.BeginInvoke()
                    Item = $item
                    Processed = $false
                }
            }
        }
        
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(200)
        $timer.Add_Tick({
            $allDone = $true
            foreach ($job in $jobs) {
                if ($job.AsyncResult.IsCompleted -and -not $job.Processed) {
                    $job.Processed = $true
                    $pingResult = $job.Pipeline.EndInvoke($job.AsyncResult)
                    $job.Pipeline.Dispose()
                    if ($pingResult) {
                        $job.Item.StatusColor = "#4CAF50" # Vert
                    } else {
                        $job.Item.StatusColor = "#F44336" # Rouge
                    }
                }
                if (-not $job.Processed) { $allDone = $false }
            }
            if ($allDone) {
                $timer.Stop()
                $runspacePool.Close()
                $runspacePool.Dispose()
            }
        })
        $timer.Start()
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
    Add-ToHistory $target

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
    Add-ToHistory $target

    Start-Process msra.exe -ArgumentList "/offerra $target"
})

$btnRDP.Add_Click({
    $selected = $dataGrid.SelectedItem
    if (-not $selected) { return }
    $target = $selected.Nom
    Add-ToHistory $target

    $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name -replace '[\\/:*?"<>|]', '-'
    $now = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
    $destDir = 'C:\temp\RDP'
    if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory | Out-Null }

    $tempRdp = [System.IO.Path]::Combine($env:TEMP, 'MyConnection.rdp')
    $finalRdp = "$destDir\RDP-$user-$now.rdp"

    $rdpContent = "full address:s:$target`r`nusername:s:$user`r`n"
    Set-Content -Path $tempRdp -Value $rdpContent -Encoding ASCII

    try { Move-Item -Path $tempRdp -Destination $finalRdp -Force } catch { return }
    Start-Process mstsc.exe -ArgumentList $finalRdp
})

$btnGestion.Add_Click({
    $selected = $dataGrid.SelectedItem
    if (-not $selected) { return }
    $target = $selected.Nom
    Add-ToHistory $target

    Start-Process compmgmt.msc -ArgumentList "/computer:\\$target" -Verb RunAs
})

$btnCShare.Add_Click({
    $selected = $dataGrid.SelectedItem
    if (-not $selected) { return }
    $target = $selected.Nom
    Add-ToHistory $target

    $share = "\\$target\C$"
    Start-Process explorer.exe $share -Verb RunAs
})

$btnWOL.Add_Click({
    $selected = $dataGrid.SelectedItem
    if (-not $selected) { return }
    $target = $selected.Nom
    
    # Récupérer l'adresse MAC via ARP (nécessite que le PC ait été pingé récemment ou soit dans le même sous-réseau)
    # Si le PC est éteint depuis longtemps, ARP ne fonctionnera pas. Il faudrait idéalement stocker les adresses MAC.
    # Pour cet exemple, on tente de récupérer l'adresse MAC via WMI/ARP ou on demande à l'utilisateur.
    
    $ip = $selected.IP
    if (-not $ip) {
        [System.Windows.MessageBox]::Show("Adresse IP introuvable pour $target.", "Erreur WOL", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    # Tentative de récupération de l'adresse MAC via ARP
    $arpOutput = arp -a $ip | Select-String -Pattern "([0-9a-f]{2}[:-]){5}[0-9a-f]{2}"
    $macAddress = $null
    
    if ($arpOutput) {
        $macAddress = $arpOutput.Matches.Value -replace '-', ':'
    } else {
        # Si ARP échoue, on demande l'adresse MAC à l'utilisateur
        $macAddress = [Microsoft.VisualBasic.Interaction]::InputBox("Impossible de trouver l'adresse MAC automatiquement.`nEntrez l'adresse MAC pour $target :", "Wake On LAN", "00:00:00:00:00:00")
        if ([string]::IsNullOrWhiteSpace($macAddress)) { return }
    }

    try {
        $macBytes = $macAddress.Split(':-') | ForEach-Object { [byte]("0x$_") }
        if ($macBytes.Length -ne 6) { throw "Format d'adresse MAC invalide." }

        $magicPacket = [byte[]]::new(102)
        for ($i = 0; $i -lt 6; $i++) { $magicPacket[$i] = 255 }
        for ($i = 1; $i -lt 17; $i++) {
            for ($j = 0; $j -lt 6; $j++) {
                $magicPacket[$i * 6 + $j] = $macBytes[$j]
            }
        }

        $udpClient = New-Object System.Net.Sockets.UdpClient
        $udpClient.Connect([System.Net.IPAddress]::Broadcast, 9)
        $udpClient.Send($magicPacket, $magicPacket.Length) | Out-Null
        $udpClient.Close()

        [System.Windows.MessageBox]::Show("Paquet magique envoyé à $target ($macAddress).", "Wake On LAN", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        [System.Windows.MessageBox]::Show("Erreur lors de l'envoi du paquet WOL : $_", "Erreur WOL", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$btnReboot.Add_Click({
    $selected = $dataGrid.SelectedItem
    if (-not $selected) { return }
    $target = $selected.Nom
    
    $result = [System.Windows.MessageBox]::Show(
        "Êtes-vous sûr de vouloir redémarrer l'ordinateur $target ?",
        "Confirmation de redémarrage",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    
    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            Restart-Computer -ComputerName $target -Force -ErrorAction Stop
            [System.Windows.MessageBox]::Show("La commande de redémarrage a été envoyée à $target.", "Redémarrage", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        } catch {
            [System.Windows.MessageBox]::Show("Erreur lors du redémarrage de $target : $_", "Erreur", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }
})

if (-not ($args -contains '-ProfileManager')) {
    $window.Dispatcher.InvokeAsync({
        Start-Sleep -Seconds 2
        if (Test-UpdateAvailable) {
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
    
    $window.ShowDialog() | Out-Null
}