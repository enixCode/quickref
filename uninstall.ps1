#Requires -Version 5
<#
  uninstall.ps1
  Arrete le resident, retire le demarrage auto, supprime %LOCALAPPDATA%\quickref.
#>
$ErrorActionPreference = 'SilentlyContinue'
Set-Location $env:USERPROFILE

$InstallDir = Join-Path $env:LOCALAPPDATA 'quickref'
function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }

Write-Step 'Arret du resident'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'Show-QuickRef\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Start-Sleep -Milliseconds 400

Write-Step 'Retrait du demarrage auto'
Remove-Item (Join-Path ([Environment]::GetFolderPath('Startup')) 'quickref.lnk') -Force

Write-Step "Suppression de $InstallDir"
Remove-Item $InstallDir -Recurse -Force

Write-Host ''
Write-Host 'quickref desinstalle.' -ForegroundColor Green
