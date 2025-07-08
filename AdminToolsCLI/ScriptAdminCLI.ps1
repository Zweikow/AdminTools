param(
    [string]$Recherche
)

Import-Module ActiveDirectory -ErrorAction SilentlyContinue

function Search-ComputersAD($search) {
    $results = @()
    try {
        $adResults = Get-ADComputer -Server "st-paul.dom" -Filter {
            (Name -like "*$search*") -or (Description -like "*$search*")
        } -Property Name, Description
        foreach ($comp in $adResults) {
            $results += [PSCustomObject]@{
                Name        = $comp.Name
                Type        = "Ordinateur"
                Description = $comp.Description
            }
        }
    } catch {
        Write-Error "Erreur lors de la recherche AD : $_"
    }
    return $results
}

if (-not $Recherche) {
    $Recherche = Read-Host "Entrez le nom ou la description à rechercher"
}

$results = Search-ComputersAD $Recherche

if ($results.Count -eq 0) {
    Write-Host "Aucun ordinateur trouvé."
    exit
}

# Affichage des résultats
$results | Format-Table -AutoSize

# Sélection de l'ordinateur
$selection = Read-Host "Entrez le numéro de la ligne de l'ordinateur à sélectionner (1-$($results.Count))"
if ($selection -notmatch '^[0-9]+$' -or [int]$selection -lt 1 -or [int]$selection -gt $results.Count) {
    Write-Host "Sélection invalide."
    exit
}
$ordi = $results[[int]$selection - 1]

Write-Host "Actions disponibles pour $($ordi.Name) :"
Write-Host "1. RDP"
Write-Host "2. MSRA"
Write-Host "3. CompMgmt"
Write-Host "4. C$"
$action = Read-Host "Entrez le numéro de l'action à effectuer"

switch ($action) {
    '1' { Start-Process "mstsc.exe" -ArgumentList "/v:$($ordi.Name)" }
    '2' { Start-Process "msra.exe" -ArgumentList "/offerra $($ordi.Name)" }
    '3' { Start-Process "compmgmt.msc" -ArgumentList "/computer:$($ordi.Name)" }
    '4' { Start-Process "explorer.exe" -ArgumentList "\\$($ordi.Name)\c$" }
    default { Write-Host "Action inconnue." }
} 