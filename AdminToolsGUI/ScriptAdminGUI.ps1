# Script de connexion à distance PowerShell et MSRA
# Version: 2.0 - Compatible PowerShell 7.5
# Encodage : UTF-8
 
# Configuration de l'encodage
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
 
function Get-DefaultCredential {
    param(
        [Parameter(Mandatory=$false)]
        [string]$DefaultUsername = "st-paul\sahbaeriswyl"
    )
   
    try {
        Write-Host "Utilisateur par défaut : $DefaultUsername" -ForegroundColor Cyan
        $securePass = Read-Host -AsSecureString "Entrez le mot de passe pour $DefaultUsername"
        $cred = New-Object System.Management.Automation.PSCredential($DefaultUsername, $securePass)
        # Test des identifiants
        if (-not $cred.GetNetworkCredential().Password) {
            throw "Mot de passe invalide"
        }
        return $cred
    }
    catch {
        Write-Error "Erreur lors de la création des identifiants : $_"
        return $null
    }
}
 
function Test-ValidIPAddress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$IPAddress
    )
   
    return [System.Net.IPAddress]::TryParse($IPAddress, [ref][System.Net.IPAddress]::Loopback)
}
 
function Test-DNSResolution {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
   
    try {
        $result = Resolve-DnsName -Name $ComputerName -ErrorAction Stop
        return $result.IPAddress | Select-Object -First 1
    }
    catch {
        return $null
    }
}
 
function Get-ComputerIPAddress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
   
    try {
        # Essayer d'abord la résolution DNS
        $ipAddress = Test-DNSResolution -ComputerName $ComputerName
        if ($ipAddress) {
            return $ipAddress
        }
       
        # Rechercher dans l'AD
        $computer = Get-ADComputer -Filter "Name -eq '$ComputerName'" -Properties IPv4Address -ErrorAction Stop
        if ($computer.IPv4Address) {
            return $computer.IPv4Address
        }
       
        Write-Warning "Impossible de résoudre l'adresse IP pour $ComputerName"
        return $null
    }
    catch {
        Write-Error "Erreur lors de la résolution de l'adresse IP : $_"
        return $null
    }
}
 
function Connect-AdminCShare {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$Credential
    )
    try {
        $username = $Credential.UserName
        $password = $Credential.GetNetworkCredential().Password
        $netUseCmd = "net use \\$ComputerName\C$ /user:$username $password"
        Write-Host "Connexion au partage \\$ComputerName\C$ avec $username..." -ForegroundColor Cyan
        cmd.exe /c $netUseCmd
        Write-Host "Connexion terminée. Ouvrir l'explorateur..." -ForegroundColor Green
        Start-Process "explorer.exe" "\\$ComputerName\C$"
    }
    catch {
        Write-Error "Erreur lors de la connexion au partage C$ : $_"
    }
}
 
 
function Open-PSSessionIfOnline {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$Credential
    )
   
    try {
        $ipAddress = if (Test-ValidIPAddress -IPAddress $ComputerName) {
            $ComputerName
        } else {
            Get-ComputerIPAddress -ComputerName $ComputerName
        }
 
        if (-not $ipAddress) { return }
 
        Write-Host "Test de connexion vers $ipAddress..." -ForegroundColor Cyan
        if (Test-Connection -TargetName $ipAddress -Count 1 -Quiet) {
            Write-Host "Connexion réussie, ouverture de session PowerShell..." -ForegroundColor Green
 
            # Lancer directement une session PowerShell avec les paramètres WinRM
            $arguments = @(
                "-NoExit",
                "-ExecutionPolicy", "Bypass",
                "-Command", "& {
                    `$Host.UI.RawUI.WindowTitle = 'Session PowerShell - $ipAddress'
                    Write-Host 'Connexion à $ipAddress...' -ForegroundColor Cyan
                    `$credential = Import-Clixml -Path '$env:TEMP\temp_cred.xml'
                    `$sessionOption = New-PSSessionOption -NoMachineProfile
                    `$session = New-PSSession -ComputerName '$ipAddress' -Credential `$credential -SessionOption `$sessionOption
                    if (`$session) {
                        Write-Host 'Connexion établie' -ForegroundColor Green
                        Enter-PSSession -Session `$session
                    }
                    Remove-Item -Path '$env:TEMP\temp_cred.xml' -Force
                }"
            )
 
            # Sauvegarder temporairement les identifiants
            $Credential | Export-Clixml -Path "$env:TEMP\temp_cred.xml" -Force
 
            # Déterminer la version de PowerShell à utiliser
            $pwsh = "C:\Program Files\PowerShell\7\pwsh.exe"
            if (-not (Test-Path $pwsh)) {
                $pwsh = "powershell.exe"
            }
 
            Write-Host "`nOuverture de la session dans une nouvelle fenêtre..." -ForegroundColor Cyan
            Start-Process $pwsh -ArgumentList $arguments -Wait
 
            # Nettoyer les identifiants si le fichier existe encore
            if (Test-Path "$env:TEMP\temp_cred.xml") {
                Remove-Item -Path "$env:TEMP\temp_cred.xml" -Force
            }
        }
        else {
            Write-Warning "L'ordinateur $ComputerName ($ipAddress) ne répond pas"
            Start-Sleep -Seconds 2
        }
    }
    catch {
        Write-Error "Erreur de session PowerShell: $_"
        Start-Sleep -Seconds 2
    }
}
 
# === Nouvelle fonction pour Windows Update ===
function Start-WindowsUpdateScan {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$Credential
    )
   
    try {
        $ipAddress = if (Test-ValidIPAddress -IPAddress $ComputerName) {
            $ComputerName
        } else {
            Get-ComputerIPAddress -ComputerName $ComputerName
        }
 
        if (-not $ipAddress) { return }
 
        Write-Host "Test de connexion vers $ipAddress..." -ForegroundColor Cyan
        if (Test-Connection -TargetName $ipAddress -Count 1 -Quiet) {
            Write-Host "Connexion réussie, lancement de la recherche de mises à jour..." -ForegroundColor Green
 
            $result = Invoke-Command -ComputerName $ipAddress -Credential $Credential -ScriptBlock {
                try {
                    # Démarrer la recherche de mises à jour
                    $startScan = UsoClient StartScan
                    Start-Sleep -Seconds 2
                   
                    # Vérifier l'état des mises à jour
                    $updateState = Get-CimInstance -ClassName Win32_OperatingSystem |
                                 Select-Object -Property @{Name='LastBootUpTime';Expression={$_.LastBootUpTime}}
                   
                    "✅ Recherche de mises à jour lancée"
                    "📅 Dernier redémarrage : $($updateState.LastBootUpTime)"
                }
                catch {
                    "❌ Erreur lors de la recherche : $_"
                }
            }
           
            $result | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
            Write-Host "`nAppuyez sur une touche pour continuer..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
        else {
            Write-Warning "L'ordinateur $ComputerName ($ipAddress) ne répond pas"
            Start-Sleep -Seconds 2
        }
    }
    catch {
        Write-Error "Erreur lors du lancement des mises à jour : $_"
        Start-Sleep -Seconds 2
    }
}
function Find-ADComputer {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SearchString
    )
   
    try {
        # Vérifier le module AD
        if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) {
            Import-Module ActiveDirectory -ErrorAction Stop
        }
 
        if ([string]::IsNullOrWhiteSpace($SearchString)) {
            Write-Warning "Veuillez entrer un critère de recherche valide."
            return $null
        }
 
        # Construction du filtre de recherche
        $filter = "(Name -like '*$SearchString*') -or " +
                 "(Description -like '*$SearchString*')"
 
        # Si c'est une adresse IP partielle
        if ($SearchString -match '^\d{1,3}(\.\d{1,3}){0,3}$') {
            $filter = "$filter -or (IPv4Address -like '*$SearchString*')"
        }
 
        # Recherche avec filtre étendu
        $computers = Get-ADComputer -Filter $filter -Properties Name, IPv4Address, Description
 
        if (-not $computers) {
            Write-Warning "Aucun ordinateur trouvé."
            return $null
        }
 
        Write-Host "`nOrdinateurs trouvés:" -ForegroundColor Cyan
        $i = 1
        $computersArray = @($computers)
        $computersArray | ForEach-Object {
            $ipInfo = if ($_.IPv4Address) { " ($($_.IPv4Address))" } else { "" }
            $descInfo = if ($_.Description) { " - $($_.Description)" } else { "" }
            Write-Host "[$i] $($_.Name)$ipInfo$descInfo" -ForegroundColor Yellow
            $i++
        }
 
        do {
            $selection = Read-Host "`nChoisissez un ordinateur (1-$($computersArray.Count), Q pour quitter)"
            if ($selection -eq 'Q') {
            return $null
            }
            if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $computersArray.Count) {
            return $computersArray[$selection-1].Name
            }
            Write-Warning "Sélection invalide, réessayez"
        } while ($true)
    }
    catch {
        Write-Error "Erreur lors de la recherche d'ordinateur : $_"
        return $null
    }
}
 
function Start-RDPConnection {
    param(
        [string]$DefaultUsername = "St-Paul\sahbaeriswyl",
        [string]$RdpFilePath = "$env:TEMP\MyConnection.rdp"
    )
 
    try {
        # Demander le nom de l'hôte distant
        if ($ComputerName) {
            $useExistingComputer = Read-Host "Voulez-vous utiliser l'ordinateur déjà sélectionné ($ComputerName) ? (O/N)"
            if ($useExistingComputer -match '^[oOyY]') {
            $RemoteHost = $ComputerName
            } else {
            $RemoteHost = Read-Host "Entrez le nom de l'hôte distant (ou l'adresse IP)"
            }
        } else {
            $RemoteHost = Read-Host "Entrez le nom de l'hôte distant (ou l'adresse IP)"
        }
 
        # Demander si on utilise le compte Windows actuel
        $useCurrentUser = Read-Host "Souhaitez-vous utiliser votre nom d'utilisateur Windows actuel ? (O/N)"
 
        if ($useCurrentUser -match '^[oOyY]') {
            $Username = "$env:USERDOMAIN\$env:USERNAME"
        } else {
            $useDefaultUser = Read-Host "Souhaitez-vous utiliser l'utilisateur par défaut ($DefaultUsername) ? (O/N)"
            if ($useDefaultUser -match '^[oOyY]') {
                $Username = $DefaultUsername
            } else {
                $Username = Read-Host "Entrez le nom d'utilisateur (format : DOMAINE\\utilisateur)"
            }
 
            # Saisie sécurisée du mot de passe
            $SecurePassword = Read-Host "Mot de passe" -AsSecureString
            # Conversion du SecureString en texte clair
            $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
            $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
           
            # Enregistrement des identifiants
            cmdkey /generic:"TERMSRV/$RemoteHost" /user:"$Username" /pass:"$PlainPassword"
           
            # Nettoyage mémoire
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Ptr)
            Write-Host "`n✅ Identifiants enregistrés pour $RemoteHost" -ForegroundColor Green
        }
 
        # Contenu du fichier RDP
        $RdpContent = @"
full address:s:$RemoteHost
username:s:$Username
authentication level:i:2
prompt for credentials:i:0
enablecredsspsupport:i:1
screen mode id:i:2
desktopwidth:i:1920
desktopheight:i:1080
session bpp:i:32
compression:i:1
keyboardhook:i:2
audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:1
allow desktop composition:i:1
disable full window drag:i:0
disable menu anims:i:0
disable themes:i:0
bitmapcachepersistenable:i:1
"@
 
        # Écriture du fichier
        $RdpContent | Out-File -Encoding ASCII -FilePath $RdpFilePath
        Write-Host "Fichier RDP généré : $RdpFilePath" -ForegroundColor Cyan
 
        # Démarrer la session RDP
        Start-Process "mstsc.exe" -ArgumentList $RdpFilePath -Wait
 
        # Nettoyage
        if (Test-Path $RdpFilePath) {
            Remove-Item -Path $RdpFilePath -Force
        }
       
        if (-not $useCurrentUser) {
            cmdkey /delete:"TERMSRV/$RemoteHost"
        }
    }
    catch {
        Write-Error "Une erreur s'est produite : $_"
    }
}
 
# Exemple d'utilisation de la fonction
# Start-RDPConnection
function Remove-UserProfile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$Credential
    )
   
    try {
        $ipAddress = if (Test-ValidIPAddress -IPAddress $ComputerName) {
            $ComputerName
        } else {
            Get-ComputerIPAddress -ComputerName $ComputerName
        }
 
        if (-not $ipAddress) { return }
 
        Write-Host "Test de connexion vers $ipAddress..." -ForegroundColor Cyan
        if (Test-Connection -TargetName $ipAddress -Count 1 -Quiet) {
            Write-Host "Connexion réussie, récupération des profils utilisateurs..." -ForegroundColor Green
 
            # Créer une session avec les droits administratifs
            $sessionOption = New-PSSessionOption -NoMachineProfile
            $session = New-PSSession -ComputerName $ipAddress -Credential $Credential -SessionOption $sessionOption
           
            if ($session) {
                try {
                    # Récupérer la liste des profils
                    $profiles = Invoke-Command -Session $session -ScriptBlock {
                        Get-CimInstance -Class Win32_UserProfile |
                        Where-Object { $_.Special -eq $false } |
                        Select-Object LocalPath, LastUseTime, SID
                    }
 
                    if ($profiles.Count -eq 0) {
                        Write-Host "Aucun profil utilisateur trouvé sur $ComputerName." -ForegroundColor Yellow
                        return
                    }
 
                    # Afficher la liste des profils
                    Write-Host "`nProfils utilisateurs disponibles sur $ComputerName :" -ForegroundColor Cyan
                    for ($i = 0; $i -lt $profiles.Count; $i++) {
                        $lastUse = if ($profiles[$i].LastUseTime) {
                            $profiles[$i].LastUseTime.ToString("dd/MM/yyyy HH:mm:ss")
                        } else {
                            "Non disponible"
                        }
                        Write-Host "[$($i+1)] $($profiles[$i].LocalPath) - Dernière utilisation : $lastUse" -ForegroundColor Yellow
                    }
 
                    # Demander la sélection
                    $selection = Read-Host "`nEntrez les numéros des profils à supprimer (séparés par une virgule, Q pour quitter)"
                   
                    if ($selection -eq "Q") { return }
 
                    # Convertir la sélection en tableau
                    $indexes = $selection -split "," | ForEach-Object { $_.Trim() -as [int] }
                    $validIndexes = $indexes | Where-Object { $_ -ge 1 -and $_ -le $profiles.Count }
 
                    if ($validIndexes.Count -eq 0) {
                        Write-Host "Sélection invalide. Aucune action effectuée." -ForegroundColor Yellow
                        return
                    }
 
                    # Afficher les profils sélectionnés et demander confirmation
                    $profilesToDelete = $validIndexes | ForEach-Object { $profiles[$_-1] }
                    Write-Host "`nProfils sélectionnés pour suppression :" -ForegroundColor Red
                    $profilesToDelete | ForEach-Object { Write-Host $_.LocalPath }
 
                    $confirmation = Read-Host "`nÊtes-vous sûr de vouloir supprimer ces profils ? (O/N)"
                    if ($confirmation -ne "O") {
                        Write-Host "Opération annulée." -ForegroundColor Yellow
                        return
                    }
 
                    # Supprimer les profils
                    foreach ($profile in $profilesToDelete) {
                        Write-Host "`nSuppression du profil $($profile.LocalPath)..." -ForegroundColor Cyan
                        $result = Invoke-Command -Session $session -ScriptBlock {
                            param($sid)
                            try {
                                $profileToDelete = Get-CimInstance -Class Win32_UserProfile |
                                                 Where-Object { $_.SID -eq $sid }
                                if ($profileToDelete) {
                                    Remove-CimInstance -InputObject $profileToDelete
                                    $true
                                } else {
                                    $false
                                }
                            }
                            catch {
                                Write-Error $_
                                $false
                            }
                        } -ArgumentList $profile.SID
 
                        if ($result) {
                            Write-Host "Profil $($profile.LocalPath) supprimé avec succès." -ForegroundColor Green
                        } else {
                            Write-Host "Échec de la suppression du profil $($profile.LocalPath)." -ForegroundColor Red
                        }
                    }
                }
                finally {
                    Remove-PSSession -Session $session
                }
            }
        }
        else {
            Write-Warning "L'ordinateur $ComputerName ($ipAddress) ne répond pas"
            Start-Sleep -Seconds 2
        }
    }
    catch {
        Write-Error "Erreur lors de la gestion des profils utilisateurs: $_"
        Start-Sleep -Seconds 2
    }
}
function Open-ComputerManagement {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$Credential
    )
   
    try {
        Write-Host "Lancement de CMD avec les identifiants par défaut..." -ForegroundColor Cyan
 
        # Lancer CMD avec les identifiants spécifiés
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = "cmd.exe"
        $startInfo.Arguments = "/k compmgmt.msc /computer:$ComputerName"
        $startInfo.Verb = "RunAs"
        $startInfo.UseShellExecute = $true  # Doit être true pour utiliser Verb
       
        # Démarrer le processus
        $process = [System.Diagnostics.Process]::Start($startInfo)
        if ($process) {
            Write-Host "CMD lancé avec succès" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Erreur lors du lancement de CMD : $_"
    }
}
 
# Programme principal
try {
    Write-Host "=== Script de connexion à distance ===" -ForegroundColor Cyan
    Write-Host "Compatible PowerShell 7.5" -ForegroundColor Gray
 
    do {
        Write-Host "`n=== Menu Principal ===" -ForegroundColor Cyan
        $searchString = Read-Host "Nom d'ordinateur ou IP (Q pour quitter)"
 
        if ($searchString -eq "Q") { break }
 
        $ComputerName = if (Test-ValidIPAddress -IPAddress $searchString) {
            Write-Host "IP valide: $searchString" -ForegroundColor Green
            $searchString
        } else {
            Find-ADComputer -SearchString $searchString
        }
 
        if ($ComputerName) {
            $ipAddress = if (Test-ValidIPAddress -IPAddress $ComputerName) {
                $ComputerName
            } else {
                Get-ComputerIPAddress -ComputerName $ComputerName
            }
 
            if ($ipAddress -and (Test-Connection -TargetName $ipAddress -Count 1 -Quiet)) {
                Write-Host "`nConnexion possible à $ComputerName ($ipAddress)" -ForegroundColor Green
               
            do {
                Write-Host "`nType de connexion:" -ForegroundColor Cyan
                Write-Host "[1] Session PowerShell" -ForegroundColor Yellow
                Write-Host "[2] Assistance à distance (MSRA)" -ForegroundColor Yellow
                Write-Host "[3] Manage profil utilisateur" -ForegroundColor Yellow
                Write-Host "[4] Session RDP" -ForegroundColor Yellow
                Write-Host "[5] Gestion de l'ordinateur" -ForegroundColor Yellow
                Write-Host "[6] Connexion au partage C$ (admin)" -ForegroundColor Yellow
                Write-Host "[7] Lancer la recherche de mises à jour" -ForegroundColor Yellow
                Write-Host "[8] Retour au menu principal" -ForegroundColor Yellow
                Write-Host "[Q] Quitter" -ForegroundColor Yellow
                $choice = Read-Host "`nChoix"
               
                switch ($choice) {
                        "1" {
                            Write-Host "`nUtiliser les identifiants par défaut ? (O/N)" -ForegroundColor Cyan
                            if ((Read-Host) -eq "O") {
                                $Credential = Get-DefaultCredential
                            } else {
                                $Credential = Get-Credential -Message "Identifiants de connexion"
                            }
                           
                            if ($Credential) {
                                Open-PSSessionIfOnline -ComputerName $ComputerName -Credential $Credential
                            }
                            break
                        }
                        "2" {
                            Start-Process "msra.exe" -ArgumentList "/offerRA $ComputerName"
                            break
                        }
                        "3" {
                            Write-Host "`nUtiliser les identifiants par défaut ? (O/N)" -ForegroundColor Cyan
                            if ((Read-Host) -eq "O") {
                                $Credential = Get-DefaultCredential
                            } else {
                                $Credential = Get-Credential -Message "Identifiants de connexion"
                            }
                           
                            if ($Credential) {
                                Remove-UserProfile -ComputerName $ComputerName -Credential $Credential
                            }
                            break
                        }
                        "4" {
                            Start-RDPConnection
                            break
                        }
                        "5" {
                            Open-ComputerManagement -ComputerName $ComputerName # -Credential $Credential      
                            break
                        }
                        "6" {
                            Write-Host "`nUtiliser les identifiants par défaut ? (O/N)" -ForegroundColor Cyan
                            if ((Read-Host) -eq "O") {
                                $Credential = Get-DefaultCredential
                            } else {
                                $Credential = Get-Credential -Message "Identifiants administrateur pour C$"
                            }
                            if ($Credential) {
                                Connect-AdminCShare -ComputerName $ComputerName -Credential $Credential
                            }
                            break
                        }
                        "7" {
                            Write-Host "`nUtiliser les identifiants par défaut ? (O/N)" -ForegroundColor Cyan
                            if ((Read-Host) -eq "O") {
                                $Credential = Get-DefaultCredential
                            } else {
                                $Credential = Get-Credential -Message "Identifiants de connexion"
                            }
                           
                            if ($Credential) {
                                Start-WindowsUpdateScan -ComputerName $ComputerName -Credential $Credential
                            }
                            break
                        }
                        "8" { break }
                        "Q" { exit }
                        default { Write-Warning "Option invalide" }
                    }
                } while ($choice -notin "1","2","3","4","5","6","7","8","Q")
            } else {
                Write-Warning "L'ordinateur $ComputerName n'est pas accessible"
                Start-Sleep -Seconds 2
            }
        }
    } while ($true)
}
catch {
    Write-Error "Erreur générale: $_"
}
finally {
    Get-PSSession | Remove-PSSession -ErrorAction SilentlyContinue
    Write-Host "`nFin du script" -ForegroundColor Cyan
}