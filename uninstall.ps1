#Requires -Version 5
<#
  uninstall.ps1
  Ferme la fenetre, retire le raccourci/touche globale, supprime %LOCALAPPDATA%\quickref.
#>
$ErrorActionPreference = 'SilentlyContinue'
Set-Location $env:USERPROFILE

$InstallDir = Join-Path $env:LOCALAPPDATA 'quickref'
function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }

Write-Step 'Fermeture de la fenetre eventuelle'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'Show-QuickRef\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Write-Step 'Retrait du raccourci / touche globale'
Remove-Item (Join-Path ([Environment]::GetFolderPath('Programs')) 'quickref.lnk') -Force

Write-Step "Suppression de $InstallDir"
Remove-Item $InstallDir -Recurse -Force

Write-Host ''
Write-Host 'quickref desinstalle.' -ForegroundColor Green
