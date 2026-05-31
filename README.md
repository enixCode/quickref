# quickref

Un aide-mémoire en surimpression : une touche affiche une fenêtre sans bords avec une **grille de raccourcis**, la même touche la referme. Idéal pour garder tes raccourcis VSCode + Vim à portée de main sans qu'ils encombrent l'écran.

100% standard Windows : PowerShell + WPF (inclus dans Windows). Rien à installer d'autre. Le moteur de grille natif de WPF (`<Grid>`) gère la mise en page, donc l'affichage est fiable.

- **Grille configurable** : tu choisis dans `config.json` combien de lignes et de colonnes, et ce que contient chaque case.
- **Auto-style** : dans chaque raccourci, la **touche** (avant le `=`) s'affiche en couleur d'accent, l'**action** en gris. Lisible d'un coup d'œil.
- **Ouverture instantanée** : un petit process reste en fond (WinForms déjà chargé, fenêtre pré-construite).
- **Toggle** : la même touche ouvre puis ferme. Se ferme aussi sur **Échap**, un **clic**, ou perte de focus.
- **Ne recouvre jamais le curseur** : s'ouvre sur l'écran où est la souris, à un emplacement libre.
- Touche globale **native** (`RegisterHotKey`), fiable. Démarre automatiquement à l'ouverture de session.
- **Mise à jour automatique** depuis GitHub (ton `config.json` est préservé).

## Installation

### En une ligne (recommandé)

```powershell
irm https://raw.githubusercontent.com/enixCode/quickref/main/install.ps1 | iex
```

### One-click (depuis un clone)

Double-clique **`Install-QuickRef.cmd`**.

Aucun droit administrateur nécessaire. L'installation copie quickref dans `%LOCALAPPDATA%\quickref`, l'ajoute au démarrage de Windows, et lance le résident. Touche par défaut : **`Ctrl+Alt+W`** (déclenchable d'une main gauche sur AZERTY).

## Mise à jour

**Automatique** au démarrage (compare `VERSION` local et GitHub, préserve `config.json`). Pour forcer : relance l'installation.

## Désinstallation

Double-clique **`Uninstall-QuickRef.cmd`**, ou :

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\quickref\uninstall.ps1"
```

## Personnalisation : la grille

Édite `%LOCALAPPDATA%\quickref\config.json`, puis **relance le résident** (double-clic sur `Start-QuickRef.vbs`, ou rouvre ta session).

La grille se définit par un nombre de lignes (`rows`) et colonnes (`cols`), et une liste de **cases** (`cells`) que tu places en `row`/`col` :

```json
{
  "hotkey": "Ctrl+Alt+W",
  "font": { "name": "Consolas", "size": 12 },
  "padding": 24,
  "lineSpacing": 7,
  "separator": "=",
  "closeOnFocusLost": true,
  "footer": "Echap pour fermer",
  "colors": {
    "background": [24, 24, 28],
    "foreground": [210, 210, 214],
    "accent": [96, 230, 150],
    "border": [96, 230, 150]
  },
  "grid": {
    "rows": 2,
    "cols": 3,
    "colGap": 46,
    "rowGap": 22,
    "cells": [
      { "row": 0, "col": 0, "title": "NAVIGATION", "items": [
          "Ctrl+P = ouvrir un fichier",
          "Ctrl+Shift+P = palette de commandes"
      ] },
      { "row": 0, "col": 1, "title": "VIM", "items": [
          "dd = couper la ligne",
          "yy / p = copier / coller"
      ] }
    ]
  }
}
```

### Réglages

| Clé | Rôle |
|---|---|
| `hotkey` | touche globale, ex. `"Ctrl+Alt+W"` (modificateurs `Ctrl` `Alt` `Shift` `Win` ; touche : lettre, `F1`-`F12`, `Space`) |
| `font.name` / `font.size` | police et taille |
| `padding` | marge intérieure de la fenêtre (px) |
| `lineSpacing` | espace entre les lignes d'une case (px) |
| `separator` | caractère qui sépare la touche de l'action (défaut `=`) ; la partie avant est colorée en accent |
| `closeOnFocusLost` | `true` = se ferme quand on clique ailleurs |
| `footer` | petite ligne grise en bas (optionnel) |
| `colors.*` | `[R, G, B]` : `background`, `foreground` (action), `accent` (touche + titres), `border` |

### Grille (`grid`)

| Clé | Rôle |
|---|---|
| `rows` / `cols` | nombre de lignes et de colonnes |
| `colGap` / `rowGap` | espacement entre colonnes / entre lignes (px) |
| `cells` | liste des cases ; chaque case a `row`, `col`, `title`, et `items` (les raccourcis) |

La fenêtre se dimensionne automatiquement au contenu. Une case vide (aucune `cell` à cette position) laisse juste un espace.

## Keychron

Dans le logiciel Keychron (VIA / Keychron Launcher), mappe ta touche pour qu'elle **envoie** `Ctrl+Alt+W` (ou la combinaison choisie dans `config.json`).

## Liens utiles

- **Raccourcis clavier VSCode (Windows)** : https://code.visualstudio.com/docs/getstarted/keybindings
- **PDF officiel des raccourcis VSCode (Windows)** : https://code.visualstudio.com/shortcuts/keyboard-shortcuts-windows.pdf
- **Extension VSCodeVim (Marketplace)** : https://marketplace.visualstudio.com/items?itemName=vscodevim.vim
- **VSCodeVim (dépôt + liste des commandes supportées)** : https://github.com/VSCodeVim/Vim
- **Personnaliser ses keybindings VSCode** : https://code.visualstudio.com/docs/getstarted/keybindings#_advanced-customization

## Architecture

```
quickref/
├─ Install-QuickRef.cmd     double-clic pour installer
├─ Uninstall-QuickRef.cmd   double-clic pour desinstaller
├─ install.ps1              installe (local OU distant via irm|iex), ajoute au demarrage
├─ uninstall.ps1           arrete le resident, retire du demarrage, supprime
├─ Start-QuickRef.vbs       lanceur silencieux (-Sta, sans console)
├─ config.json             la grille + les reglages
├─ VERSION                 version (semver), base de l'auto-update
├─ .gitignore
└─ src/
   ├─ Show-QuickRef.ps1     le resident : fenetre WPF, grille native, hotkey, toggle
   └─ AutoUpdate.ps1        verifie GitHub au demarrage et se met a jour seul
```

### Comment ça marche

- `src/Show-QuickRef.ps1` tourne en fond. Il lit la grille du `config.json` et construit une fenêtre **WPF** : un `<Grid>` avec une colonne/ligne par cellule, WPF gère la mise en page tout seul (pas de calcul pixel, pas de crash de layout).
- Une fenêtre-message C# capte la touche globale via `RegisterHotKey`. À l'appui : **Afficher / Masquer** la fenêtre WPF → instantané.
- Au démarrage, `AutoUpdate.ps1` vérifie GitHub et se met à jour si besoin.
- `Start-QuickRef.vbs` le démarre sans console.

## Prérequis

- Windows 10 ou 11
- PowerShell 5.1 (intégré)

## Licence

MIT.
