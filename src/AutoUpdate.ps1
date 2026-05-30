# AutoUpdate.ps1
# Verifie au demarrage du resident s'il existe une version plus recente sur GitHub.
# Tout est defensif : pas de reseau / erreur => on ne bloque jamais le lancement.

$script:QuickRefRepo   = 'enixCode/quickref'
$script:QuickRefBranch = 'main'

function Get-QuickRefLocalVersion {
    param([string]$Root)
    $vf = Join-Path $Root 'VERSION'
    if (-not (Test-Path $vf)) { return [version]'0.0.0' }
    try { return [version]((Get-Content $vf -Raw).Trim()) } catch { return [version]'0.0.0' }
}

function Get-QuickRefRemoteVersion {
    $url = "https://raw.githubusercontent.com/$($script:QuickRefRepo)/$($script:QuickRefBranch)/VERSION"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $raw = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5).Content
        return [version]($raw.Trim())
    } catch { return $null }
}

function Invoke-QuickRefAutoUpdate {
    # Retourne $true si une mise a jour a ete appliquee (l'appelant doit alors relancer + sortir).
    param([string]$Root)

    $local  = Get-QuickRefLocalVersion -Root $Root
    $remote = Get-QuickRefRemoteVersion
    if ($null -eq $remote) { return $false }   # hors ligne : on lance la version actuelle
    if ($remote -le $local) { return $false }  # deja a jour

    try {
        $tmp = Join-Path $env:TEMP ('quickref-au-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $zip = Join-Path $tmp 'src.zip'
        $zipUrl = "https://github.com/$($script:QuickRefRepo)/archive/refs/heads/$($script:QuickRefBranch).zip"
        Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing -TimeoutSec 30
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        $srcDir = (Get-ChildItem -Path $tmp -Directory | Where-Object { $_.Name -like 'quickref-*' } | Select-Object -First 1).FullName
        if (-not $srcDir) { return $false }

        # Copier par-dessus l'install, en preservant le config.json de l'utilisateur.
        $userConfig = Join-Path $Root 'config.json'
        $backup = if (Test-Path $userConfig) { [System.IO.File]::ReadAllText($userConfig) } else { $null }
        Get-ChildItem -Path $srcDir -Force | Where-Object { $_.Name -ne '.git' } | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $Root -Recurse -Force
        }
        if ($backup) { [System.IO.File]::WriteAllText($userConfig, $backup) }
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false   # toute erreur => on continue avec la version actuelle
    }
}
