# quickref : installation et configuration par un agent IA

Ce fichier contient **tout** ce qu'un agent de code (Claude Code, Cursor...) doit savoir pour installer, configurer, mettre à jour et désinstaller quickref sur Windows, et pour comprendre/modifier le code.

**Pour l'utilisateur :** copie le bloc « PROMPT » ci-dessous et colle-le à ton agent. Il fera le reste, de façon interactive (il te demandera tes outils, tes raccourcis, etc.).

---

## PROMPT (à copier-coller à l'agent)

```
Tu vas installer et configurer "quickref" pour moi sur ce PC Windows, de facon
interactive (demande-moi mes preferences, ne suppose pas). quickref est un
aide-memoire en surimpression : une touche (Ctrl+Alt+W) affiche une grille de
raccourcis plein ecran, la meme touche la referme. Depot : github.com/enixCode/quickref.
Toutes les references sont dans AGENT-SETUP.md (sections plus bas) : lis-les.

Etapes :

1) INSTALLER (voir section "Installer / mettre a jour / desinstaller")
   - Lance l'installeur one-liner, puis demarre une fois : quickref.
   - Verifie qu'il tourne : Get-Process quickref.

2) ME DEMANDER MES GOUTS (interactif)
   - Quels outils je veux dans la grille ? (VSCode, Vim, terminal, git, navigation...).
   - Quelle disposition ? Propose une grille (lignes x colonnes) et son contenu.
   - Couleurs / police / marge ecran : defaut ou personnalises ?

3) SOURCES DYNAMIQUES (voir section "Reference de config.json")
   - Si j'utilise VSCode, propose de synchroniser une case sur mon
     %APPDATA%/Code/User/keybindings.json via une "source" regex. VERIFIE que le
     fichier existe avant de l'ecrire.

4) ECRIRE LA CONFIG (voir section "Reference de config.json")
   - Edite %APPDATA%\quickref\config.json : grille, couleurs, sources. Garde un
     JSON valide. Relance quickref pour appliquer (Ctrl+Alt+W ne recharge pas la
     config : arrete le process quickref et relance-le, ou rouvre ma session).

5) VERIFIER
   - Confirme que Ctrl+Alt+W affiche bien ma grille, et que les sources dynamiques
     remontent mes raccourcis.

Regles : ne mets jamais de donnees perso (email) dans un fichier ou un commit. Si
une source dynamique ne matche rien, signale-le et propose un ajustement de regex,
ne bloque pas le reste.
```

---

## Comment quickref fonctionne (pour l'agent)

- Binaire natif Windows unique (`quickref.exe`), sans runtime. GUI : **eframe/egui** (renderer OpenGL `glow`).
- Au lancement (hors `--dev`), il : **s'inscrit au démarrage automatique** (clé Run `HKCU` -> son propre chemin), écrit une **config par défaut** dans `%APPDATA%\quickref\config.json` si absente, **lance l'updater** (`quickref-update.exe`, fourni par l'installeur, en tâche de fond), puis affiche la grille sur hotkey.
- `main()` : détecte `--dev` ; sinon bootstrap (config + autostart + updater) ; charge la config ; lance `run_resident`.
- Boucle egui : `App::logic()` (chaque frame, même cachée : hotkey, fermeture, placement Win32) et `App::ui()` (peinture, seulement visible). Un **thread de pompe** réveille la boucle via `request_repaint` à chaque hotkey (réactif même caché, sans busy-loop).
- La config est lue dans cet ordre : à côté de l'exe, puis `%APPDATA%\quickref\config.json`, puis un défaut embarqué.

## Installer / mettre à jour / désinstaller

**Installer** (PowerShell) :

```powershell
powershell -c "irm https://github.com/enixCode/quickref/releases/latest/download/quickref-installer.ps1 | iex"
quickref
```

L'installeur (généré par **dist** / cargo-dist) télécharge le binaire compilé par la CI, l'installe dans `~/.cargo/bin` (sur le PATH) avec son updater. Le 1er `quickref` déclenche l'auto-inscription au démarrage et la config par défaut.

**Mettre à jour** : automatique (l'updater `quickref-update` tourne au démarrage). Pour forcer : lancer `quickref-update`.

**Désinstaller** :

```powershell
irm https://raw.githubusercontent.com/enixCode/quickref/main/uninstall.ps1 | iex
```

(Arrête le résident, retire la clé Run de démarrage, supprime `%APPDATA%\quickref` et les binaires.)

## Référence de config.json

Fichier : `%APPDATA%\quickref\config.json`. Lu **une fois au démarrage** (relancer pour appliquer). Toute clé absente prend un défaut.

| Clé | Type | Rôle | Défaut |
|---|---|---|---|
| `hotkey` | texte | touche globale. Modifs `Ctrl`/`Alt`/`Shift`/`Win` ; touche lettre, `F1`-`F12`, `Space`, `Tab`, `Enter` | `"Ctrl+Alt+W"` |
| `font.name` / `font.size` | texte / nombre | police (chargée depuis `C:\Windows\Fonts`, ex. `Consolas`), taille pt | `Consolas` / `13` |
| `lineSpacing` | nombre | espace vertical entre lignes d'une case (px) | `7` |
| `separator` | texte | sépare touche/action ; la partie avant est colorée en accent | `"="` |
| `closeOnFocusLost` | booléen | ferme à la perte de focus | `true` |
| `footer` | texte | ligne grise en bas | (vide) |
| `screenMargin` | entier | marge (px) entre la fenêtre et les bords de l'écran | `64` |
| `borderWidth` | nombre | épaisseur de bordure (px ; `0` = aucune) | `2` |
| `colors.background` / `foreground` / `accent` / `border` | `[R,G,B]` | fond / action / touche+titres / bordure | sombre / gris / vert / vert |
| `grid` | objet | `rows`, `cols`, `colGap`, `rowGap`, `cells[]` | grille 1x1 |

Chaque cellule de `grid.cells` : `row`, `col`, `title`, `items: [texte]` (statiques) et/ou `source` / `sources` (dynamiques). Les `items` s'affichent d'abord, puis les lignes des sources.

### Sources dynamiques (synchro fichier + regex)

Une case lit un fichier externe et en extrait des lignes `(touche, action)`. Exemple VSCode :

```json
{
  "row": 0, "col": 0, "title": "VSCODE",
  "source": {
    "file": "%APPDATA%/Code/User/keybindings.json",
    "regex": "\"key\"\\s*:\\s*\"([^\"]+)\"\\s*,\\s*\"command\"\\s*:\\s*\"([^\"]+)\"",
    "key": 1, "action": 2, "limit": 8,
    "replace": [ { "find": "workbench\\.action\\.", "to": "" } ]
  }
}
```

| Clé de `source` | Défaut | Rôle |
|---|---|---|
| `file` | , | chemin (résout `%VAR%` et `~`) |
| `regex` | , | regex à groupes (échapper `\`->`\\`, `"`->`\"`) |
| `key` / `action` | `1` / `2` | n° de groupe pour la touche / l'action |
| `sep` | sépar. grille | séparateur affiché |
| `limit` | 0 (illimité) | nb max de lignes |
| `ignoreCase` | `true` | regex insensible à la casse |
| `replace` | `[]` | règles `{ "find", "to" }` (regex) appliquées à la touche ET à l'action |

Pour plusieurs sources dans une case : `"sources": [ {...}, {...} ]`.

## Décisions d'archi & pièges (avant de modifier)

- **Transparence egui cassée sur Windows** (emilk/egui #4451). La fenêtre est **opaque** ; les coins arrondis viennent d'une **région Win32** (`SetWindowRgn`). Ne pas réactiver `with_transparent`.
- **eframe 0.34** : la méthode requise de `App` est `ui()` ; `logic()` (hors-peinture) tourne **même cachée**. Logique non-peinture dans `logic()`.
- **Réveil quand cachée** : thread de pompe -> `ctx.request_repaint()` à chaque hotkey ; `logic()` ne `request_repaint` que visible (résident léger au repos).
- **Toggle debouncé** (250 ms) : sinon la répétition clavier piège l'utilisateur (fenêtre qui ne se ferme plus). Ne pas revenir à une logique de parité.
- **DPI** : placement (taille/position/rayon) en pixels physiques via Win32.
- **Version** : `env!("CARGO_PKG_VERSION")` ; bumper = éditer `Cargo.toml` (et le tag de release doit correspondre).
- **Distribution** : tout passe par **dist** (`dist-workspace.toml` + `.github/workflows/release.yml`). NE PAS coder d'install/update à la main : pousser un tag `vX.Y.Z` -> la CI build et publie la Release (binaire + installeur + updater). L'app ne fait que s'auto-inscrire au démarrage et lancer l'updater.

## Carte du code (`src/`)

| Fichier | Rôle |
|---|---|
| `main.rs` | `--dev`, bootstrap (config/autostart/updater), chargement config, `run_resident` (hotkey + fenêtre), parsing hotkey, thread de pompe. |
| `app.rs` | `QuickRefApp` (impl `eframe::App`), rendu grille, toggle/fermeture, bordure, chargement police. |
| `config.rs` | structs serde du `config.json`, défauts, `compute_lines` (items + sources). |
| `sources.rs` | sources dynamiques (lecture fichier + regex + `replace`). |
| `positioning.rs` | `place_monitor` : taille = écran moins marge, Win32, DPI, coins arrondis. |
| `install.rs` | bootstrap démarrage : `config_dir` (`%APPDATA%`), `ensure_default_config`, `ensure_autostart` (clé Run), `spawn_updater`. |

## Mode dev

`quickref --dev` : cohabite avec la version installée. Accent **orange** + `[ MODE DEV ]` dans le footer, **pas d'autostart**, **pas d'update**. Permet de tester une version locale sans toucher l'installée.

## Build & distribution

```powershell
cargo build --release       # ajoute -j 1 si peu de RAM
```

Distribution : éditer `version` dans `Cargo.toml`, mettre à jour `CHANGELOG.md`, puis `git tag vX.Y.Z && git push --tags`. Le workflow GitHub Actions build dans le cloud et publie la Release (binaire + installeur PowerShell + updater). Config dans `dist-workspace.toml`.
