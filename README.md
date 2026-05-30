# quickref

Un aide-mémoire en surimpression : une touche ouvre une fenêtre sans bords affichant ton texte, la même touche la referme. Idéal pour garder tes raccourcis (VSCode, Vim, autre) à portée de main sans qu'ils encombrent l'écran.

100% standard Windows : PowerShell + WinForms. Rien à installer d'autre.

- **Ouverture instantanée** : un petit process reste en fond (WinForms déjà chargé, fenêtre pré-construite), donc l'affichage est immédiat.
- **Toggle** : la même touche ouvre puis ferme la fenêtre.
- Se ferme aussi sur **Échap**, un **clic**, ou quand elle **perd le focus**.
- **Ne recouvre jamais le curseur** : elle s'ouvre sur l'écran où est la souris, à un emplacement libre.
- Touche globale **native** (`RegisterHotKey`), fiable. Démarre automatiquement à l'ouverture de session.
- **Mise à jour automatique** : au démarrage, le résident vérifie GitHub et se met à jour seul si une nouvelle version existe (ton `config.json` est préservé).
- Texte, couleurs, police, taille, touche : tout dans `config.json`.

## Installation

### En une ligne (recommandé)

Ouvre PowerShell et colle :

```powershell
irm https://raw.githubusercontent.com/enixCode/quickref/main/install.ps1 | iex
```

### One-click (depuis un clone du repo)

Double-clique **`Install-QuickRef.cmd`**.

### En ligne de commande (depuis un clone)

```powershell
& "$env:USERPROFILE\OneDrive\Github\quickref\install.ps1"
```

Aucun droit administrateur nécessaire (tout s'installe dans ton espace utilisateur). L'installation copie quickref dans `%LOCALAPPDATA%\quickref`, l'ajoute au démarrage de Windows, et lance le résident.

La touche par défaut est **`Ctrl+Alt+W`**, choisie pour être déclenchable d'une seule main gauche sur AZERTY (W est en bas à gauche, près de Ctrl/Alt).

## Mise à jour

**Automatique** : à chaque ouverture de session, le résident compare sa version (`VERSION`) à celle de GitHub et se met à jour seul si besoin, en préservant ton `config.json`.

Pour forcer une mise à jour tout de suite, relance simplement l'installation (one-liner ou `Install-QuickRef.cmd`).

## Désinstallation

- **One-click** : double-clique **`Uninstall-QuickRef.cmd`** (présent dans le dossier du projet et dans `%LOCALAPPDATA%\quickref`).
- **Ligne de commande** :
  ```powershell
  powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\quickref\uninstall.ps1"
  ```

Ça arrête le résident, le retire du démarrage, et supprime les fichiers installés.

## Keychron

Le but : une touche dédiée du clavier. Dans le logiciel Keychron (VIA / Keychron Launcher), mappe la touche voulue pour qu'elle **envoie la combinaison** `Ctrl+Alt+W` (ou celle que tu as choisie). Windows la captera et ouvrira/fermera la fenêtre.

## Personnalisation

Édite `%LOCALAPPDATA%\quickref\config.json`, puis **relance le résident** pour appliquer (double-clic sur `%LOCALAPPDATA%\quickref\Start-QuickRef.vbs`, ou rouvre ta session).

```json
{
  "title": "Raccourcis",
  "hotkey": "Ctrl+Alt+W",
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
| `hotkey` | la touche globale, ex. `"Ctrl+Alt+W"` (modificateurs : `Ctrl`, `Alt`, `Shift`, `Win` ; touche : une lettre, `F1`-`F12`, ou `Space`) |
| `font` | police, taille, gras |
| `padding` | marge intérieure (px) |
| `lineSpacing` | espace entre les lignes (px) |
| `closeOnFocusLost` | `true` = se ferme dès qu'on clique ailleurs |
| `colors.*` | couleurs `[R, G, B]` (fond, texte, accent, bordure) |
| `lines` | les lignes affichées (la fenêtre s'adapte à leur taille) |

La fenêtre se redimensionne automatiquement au contenu.

## Architecture

```
quickref/
├─ Install-QuickRef.cmd     double-clic pour installer (appelle install.ps1)
├─ Uninstall-QuickRef.cmd   double-clic pour desinstaller (appelle uninstall.ps1)
├─ install.ps1              installe (local OU distant via irm|iex), ajoute au demarrage
├─ uninstall.ps1           arrete le resident, retire du demarrage, supprime les fichiers
├─ Start-QuickRef.vbs       lanceur silencieux (-Sta, sans console) du resident
├─ config.json             tes reglages (texte, touche, couleurs, police)
├─ VERSION                 numero de version (semver), base de l'auto-update
├─ .gitignore              fichiers ignores par git
└─ src/
   ├─ Show-QuickRef.ps1     le resident : hotkey natif, fenetre HUD, toggle, anti-curseur
   └─ AutoUpdate.ps1        verifie GitHub au demarrage et se met a jour seul
```

### Comment ça marche

- `src/Show-QuickRef.ps1` est lancé une fois (au login, ou par l'install) et **reste en fond**. Il enregistre la touche globale via `RegisterHotKey` et garde une fenêtre prête, masquée.
- À l'appui sur la touche, il fait juste **Afficher / Masquer** la fenêtre → instantané.
- Au démarrage, il appelle `AutoUpdate.ps1` : si GitHub a une version plus récente, il télécharge, remplace les fichiers (en gardant `config.json`) et se relance.
- `Start-QuickRef.vbs` le démarre **sans fenêtre console** et en mode `-Sta` (requis par WinForms).
- Le **dossier source** (ce repo) est ce que tu édites ; l'**installation** vit dans `%LOCALAPPDATA%\quickref`. `install.ps1` copie de l'un vers l'autre.

## Prérequis

- Windows 10 ou 11
- PowerShell 5.1 (intégré)

## Licence

MIT.
