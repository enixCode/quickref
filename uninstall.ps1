# quickref : desinstallation.
# Arrete le resident, retire le demarrage automatique, supprime la config et les binaires.
$ErrorActionPreference = 'SilentlyContinue'

Get-Process -Name 'quickref' | Stop-Process -Force

# Demarrage automatique.
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'quickref'

# Config utilisateur.
Remove-Item -Recurse -Force (Join-Path $env:APPDATA 'quickref')

# Binaires installes par l'installeur dist (~/.cargo/bin).
$bin = Join-Path $env:USERPROFILE '.cargo\bin'
Remove-Item -Force (Join-Path $bin 'quickref.exe')
Remove-Item -Force (Join-Path $bin 'quickref-update.exe')

Write-Host "quickref desinstalle."
