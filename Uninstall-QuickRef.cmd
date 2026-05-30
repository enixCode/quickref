@echo off
REM Uninstall-QuickRef.cmd - double-clique ce fichier pour desinstaller quickref.
REM Lance uninstall.ps1 du meme dossier (arrete le resident, retire du demarrage,
REM supprime les fichiers installes).
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
echo.
echo Termine. Tu peux fermer cette fenetre.
pause
