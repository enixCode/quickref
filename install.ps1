#Requires -Version 5
<#
  install.ps1
  Installe quickref dans %LOCALAPPDATA%\quickref et cree un raccourci avec touche globale.
  Le raccourci (.lnk dans le menu Demarrer) porte un Hotkey Windows : appuyer dessus
  ouvre/ferme la fenetre, sans aucun processus resident.
#>
$ErrorActionPreference = 'Stop'

$InstallDir = Join-Path $env:LOCALAPPDATA 'quickref'
$Hotkey     = 'Ctrl+Alt+Space'   # touche globale par defaut (ta Keychron enverra cette combo)

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }

# 1. Source = dossier courant (un clone / le repo)
if (-not ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'src\Show-QuickRef.ps1')))) {
    throw "Lance install.ps1 depuis le dossier du projet (src\Show-QuickRef.ps1 introuvable)."
}
$srcDir = $PSScriptRoot

# 2. Copier vers l'install dir, en preservant un config.json existant
Write-Step "Copie vers $InstallDir"
$userConfig = Join-Path $InstallDir 'config.json'
$backup = if (Test-Path $userConfig) { [System.IO.File]::ReadAllText($userConfig) } else { $null }
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Get-ChildItem -Path $srcDir -Force | Where-Object { $_.Name -ne '.git' } | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $InstallDir -Recurse -Force
}
if ($backup) { [System.IO.File]::WriteAllText($userConfig, $backup) }

# 3. Raccourci avec touche globale dans le menu Demarrer
Write-Step "Creation du raccourci (touche globale $Hotkey)"
$programs = [Environment]::GetFolderPath('Programs')
$lnk = Join-Path $programs 'quickref.lnk'
$vbs = Join-Path $InstallDir 'Launch-QuickRef.vbs'
$ws = New-Object -ComObject WScript.Shell
$s  = $ws.CreateShortcut($lnk)
$s.TargetPath       = 'wscript.exe'
$s.Arguments        = '"' + $vbs + '"'
$s.WorkingDirectory = $InstallDir
$s.Description       = 'quickref - aide-memoire en surimpression'
$s.Hotkey           = $Hotkey
$s.Save()

# Verifier ce que Windows a accepte comme touche
$check = $ws.CreateShortcut($lnk)
$applied = $check.Hotkey

Write-Host ''
Write-Host "quickref installe dans $InstallDir" -ForegroundColor Green
Write-Host "  Config        : $userConfig"
if ($applied) {
    Write-Host "  Touche globale: $applied" -ForegroundColor Green
} else {
    Write-Host "  Touche globale: NON appliquee (combinaison refusee par Windows)" -ForegroundColor Yellow
    Write-Host "                  Ouvre quand meme via $vbs, ou change `$Hotkey dans install.ps1."
}
Write-Host "  Raccourci     : $lnk"
Write-Host "  Desinstaller  : powershell -ExecutionPolicy Bypass -File `"$InstallDir\uninstall.ps1`""
Write-Host ''
Write-Host "Keychron : mappe ta touche pour envoyer la combinaison ci-dessus." -ForegroundColor Cyan
