@echo off
REM Install-QuickRef.cmd - double-clique ce fichier pour installer quickref.
REM Lance install.ps1 du meme dossier, sans avoir a ouvrir PowerShell.
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
echo Termine. Tu peux fermer cette fenetre.
pause
