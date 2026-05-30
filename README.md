# quickref

Un aide-mémoire en surimpression : une touche ouvre une fenêtre sans bords affichant ton texte, une touche la referme. Idéal pour garder tes raccourcis (VSCode, Vim, autre) à portée de main sans qu'ils encombrent l'écran.

100% standard Windows : PowerShell + WinForms. Rien à installer d'autre.

- **Toggle** : la même touche ouvre puis ferme la fenêtre.
- Se ferme aussi sur **Échap**, un **clic**, ou quand elle **perd le focus**.
- **Ne recouvre jamais le curseur** de la souris : elle s'ouvre sur l'écran où est la souris, à un emplacement libre (centre, sinon un coin).
- Aucun processus résident : la touche globale est portée par un raccourci Windows.
- Texte, couleurs, police, taille : tout dans `config.json`.

## Installation

```powershell
& "$env:USERPROFILE\OneDrive\Github\quickref\install.ps1"
```

Ça copie quickref dans `%LOCALAPPDATA%\quickref` et crée un raccourci avec la touche globale **`Ctrl+Alt+Space`**.

> Note : Windows interdit `Ctrl+Space` seul comme touche globale, d'où `Ctrl+Alt+Space` par défaut. Tu peux changer la combinaison en éditant `$Hotkey` en haut de `install.ps1`, puis relancer l'installation.

## Keychron

Le but : une touche dédiée du clavier. Dans le logiciel Keychron (VIA / Keychron Launcher), mappe la touche voulue pour qu'elle **envoie la combinaison** `Ctrl+Alt+Space` (ou celle que tu as choisie). Windows la captera et ouvrira/fermera la fenêtre.

## Personnalisation

Édite `%LOCALAPPDATA%\quickref\config.json` :

```json
{
  "title": "Raccourcis",
  "hotkey": "Ctrl+Alt+Space",
  "font": { "name": "Consolas", "size": 13, "bold": false },
  "padding": 26,
  "lineSpacing": 8,
  "closeOnFocusLost": true,
  "colors": {
    "background": [24, 24, 28],
    "foreground": [235, 235, 235],
    "accent": [96, 230, 150],
    "border": [96, 230, 150]
  },
  "lines": [
    "Premiere ligne d'aide-memoire",
    "Deuxieme ligne"
  ]
}
```

| Clé | Rôle |
|---|---|
| `title` | titre affiché en couleur d'accent en haut |
| `font` | police, taille, gras |
| `padding` | marge intérieure (px) |
| `lineSpacing` | espace entre les lignes (px) |
| `closeOnFocusLost` | `true` = se ferme dès qu'on clique ailleurs |
| `colors.*` | couleurs `[R, G, B]` (fond, texte, accent, bordure) |
| `lines` | les lignes affichées (la fenêtre s'adapte à leur taille) |

La fenêtre se redimensionne automatiquement au contenu. Après modif, ferme la fenêtre puis rouvre-la.

## Désinstallation

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\quickref\uninstall.ps1"
```

## Architecture

```
quickref/
├─ install.ps1            installe + crée le raccourci à touche globale
├─ uninstall.ps1          désinstallation propre
├─ Launch-QuickRef.vbs    lanceur silencieux (-Sta, sans console)
├─ config.json            réglages (texte, couleurs, police)
└─ src/
   └─ Show-QuickRef.ps1   la fenêtre : toggle, rendu, positionnement anti-curseur
```

## Prérequis

- Windows 10 ou 11
- PowerShell 5.1 (intégré)

## Licence

MIT.
