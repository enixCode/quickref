#Requires -Version 5
<#
  install.ps1
  Installe quickref dans %LOCALAPPDATA%\quickref, demarre le process resident
  et l'active au demarrage de Windows. Le resident ecoute le hotkey global natif
  (defini par "hotkey" dans config.json, defaut Ctrl+Alt+W) et affiche/masque
  la fenetre instantanement.
#>
$ErrorActionPreference = 'Stop'

$InstallDir = Join-Path $env:LOCALAPPDATA 'quickref'
function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }

# 1. Source = dossier courant (le repo / un clone)
if (-not ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'src\Show-QuickRef.ps1')))) {
    throw "Lance install.ps1 depuis le dossier du projet (src\Show-QuickRef.ps1 introuvable)."
}
$srcDir = $PSScriptRoot

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

# 4. Retirer l'ancien raccourci a hotkey (versions <= 1.0 : .lnk dans le menu Demarrer).
#    Son hotkey .lnk entrerait en conflit avec le hotkey natif du resident.
$oldLnk = Join-Path ([Environment]::GetFolderPath('Programs')) 'quickref.lnk'
if (Test-Path $oldLnk) { Remove-Item $oldLnk -Force -ErrorAction SilentlyContinue }

# 5. Demarrage automatique (le resident se relance a chaque login)
Write-Step 'Activation du demarrage automatique'
$startup = [Environment]::GetFolderPath('Startup')
$lnk     = Join-Path $startup 'quickref.lnk'
$vbs     = Join-Path $InstallDir 'Launch-QuickRef.vbs'
$ws = New-Object -ComObject WScript.Shell
$s  = $ws.CreateShortcut($lnk)
$s.TargetPath       = 'wscript.exe'
$s.Arguments        = '"' + $vbs + '"'
$s.WorkingDirectory = $InstallDir
$s.Description       = 'quickref - aide-memoire en surimpression (resident)'
$s.Save()

# 5. Lancer le resident maintenant
Write-Step 'Lancement du resident'
Start-Process wscript.exe -ArgumentList ('"' + $vbs + '"')

# 6. Lire la touche configuree (pour l'afficher)
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
Write-Host "  Desinstaller   : powershell -ExecutionPolicy Bypass -File `"$InstallDir\uninstall.ps1`""
Write-Host ''
Write-Host "Le resident tourne en fond. Appuie sur $hotkey pour ouvrir/fermer (instantane)." -ForegroundColor Cyan
Write-Host "Keychron : mappe ta touche pour envoyer $hotkey." -ForegroundColor Cyan
