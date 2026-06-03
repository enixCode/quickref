# Changelog

Toutes les modifications notables de quickref. Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/), versions selon [SemVer](https://semver.org/lang/fr/).

## [1.4.1] - 2026-06-03

### Modifié
- **Auto-update via `github.com` uniquement** (redirection `releases/latest` + zip de la release), **sans `api.github.com` ni token** : marche même pour quelqu'un de non authentifié, ou sur un réseau où l'API GitHub est bloquée. Remplace l'updater cargo-dist (`install-updater = false`).

## [1.4.0] - 2026-06-03

### Ajouté
- Réécriture complète en **Rust** (egui), binaire unique, depuis l'ancienne version PowerShell + WPF.
- HUD **plein écran moins une marge**, grille centrée, police Consolas, bordure arrondie.
- **Sources dynamiques** (regex) : synchro avec `keybindings.json` / `settings.json` VSCode.
- **Distribution via cargo-dist** : installeur PowerShell one-liner + updater, Releases GitHub.
- **Auto-inscription au démarrage** (clé Run HKCU) et auto-update au lancement.
- Mode **`--dev`** qui cohabite avec la version installée (pas d'autostart ni d'update).
