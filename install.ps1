#Requires -Version 5
<#
  install.ps1
  Installe quickref dans %LOCALAPPDATA%\quickref, demarre le resident et l'active
  au demarrage de Windows. Le resident ecoute le hotkey global natif (defini par
  "hotkey" dans config.json, defaut Ctrl+Alt+W) et affiche/masque la fenetre.

  Deux modes detectes automatiquement :
   - Local   : execute depuis un clone  -> copie les fichiers du dossier courant
   - Distant : "irm <url>/install.ps1 | iex" -> telecharge le repo depuis GitHub
#>
$ErrorActionPreference = 'Stop'

$Repo       = 'enixCode/quickref'
$Branch     = 'main'
$InstallDir = Join-Path $env:LOCALAPPDATA 'quickref'

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }

# 1. Determiner la source des fichiers (local ou telechargement)
$tmp = $null
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'src\Show-QuickRef.ps1'))) {
    $srcDir = $PSScriptRoot
    Write-Step "Source locale : $srcDir"
} else {
    Write-Step "Telechargement depuis github.com/$Repo ($Branch)"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $tmp = Join-Path $env:TEMP ('quickref-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $zip = Join-Path $tmp 'src.zip'
    Invoke-WebRequest -Uri "https://github.com/$Repo/archive/refs/heads/$Branch.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $srcDir = (Get-ChildItem -Path $tmp -Directory | Where-Object { $_.Name -like 'quickref-*' } | Select-Object -First 1).FullName
    if (-not $srcDir) { throw 'Archive invalide.' }
}

# 2. Arreter un resident eventuel
Write-Step 'Arret du resident eventuel'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'Show-QuickRef\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500

# 3. Copier vers l'install dir, en preservant un config.json existant
Write-Step "Copie vers $InstallDir"
$userConfig = Join-Path $InstallDir 'config.json'
$backup = if (Test-Path $userConfig) { [System.IO.File]::ReadAllText($userConfig) } else { $null }
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Get-ChildItem -Path $srcDir -Force | Where-Object { $_.Name -ne '.git' } | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $InstallDir -Recurse -Force
}
if ($backup) { [System.IO.File]::WriteAllText($userConfig, $backup) }

# 4. Retirer un ancien raccourci a hotkey du menu Demarrer (versions <= 1.0).
$oldLnk = Join-Path ([Environment]::GetFolderPath('Programs')) 'quickref.lnk'
if (Test-Path $oldLnk) { Remove-Item $oldLnk -Force -ErrorAction SilentlyContinue }

# 5. Demarrage automatique (le resident se relance a chaque login)
Write-Step 'Activation du demarrage automatique'
$startup = [Environment]::GetFolderPath('Startup')
$lnk     = Join-Path $startup 'quickref.lnk'
$vbs     = Join-Path $InstallDir 'Start-QuickRef.vbs'
$ws = New-Object -ComObject WScript.Shell
$s  = $ws.CreateShortcut($lnk)
$s.TargetPath       = 'wscript.exe'
$s.Arguments        = '"' + $vbs + '"'
$s.WorkingDirectory = $InstallDir
$s.Description       = 'quickref - aide-memoire en surimpression (resident)'
$s.Save()

# 6. Nettoyage du temp eventuel
if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }

# 7. Lancer le resident maintenant
Write-Step 'Lancement du resident'
Start-Process wscript.exe -ArgumentList ('"' + $vbs + '"')

# 8. Lire la touche configuree (pour l'afficher)
$hotkey = 'Ctrl+Alt+W'
try {
    $b = [System.IO.File]::ReadAllBytes($userConfig)
    $j = [System.Text.Encoding]::UTF8.GetString($b).TrimStart([char]0xFEFF) | ConvertFrom-Json
    if ($j.hotkey) { $hotkey = [string]$j.hotkey }
} catch {}

Write-Host ''
Write-Host "quickref installe dans $InstallDir" -ForegroundColor Green
Write-Host "  Touche globale : $hotkey  (modifiable dans config.json -> 'hotkey')"
Write-Host "  Config         : $userConfig"
Write-Host "  Demarrage auto : actif (le resident se relance a chaque login)"
Write-Host "  Mise a jour    : automatique au demarrage depuis GitHub"
Write-Host "  Desinstaller   : powershell -ExecutionPolicy Bypass -File `"$InstallDir\uninstall.ps1`""
Write-Host ''
Write-Host "Le resident tourne en fond. Appuie sur $hotkey pour ouvrir/fermer (instantane)." -ForegroundColor Cyan
Write-Host "Keychron : mappe ta touche pour envoyer $hotkey." -ForegroundColor Cyan
