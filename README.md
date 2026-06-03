# quickref

Aide-mémoire en surimpression : une touche affiche une **grille de raccourcis** plein écran (moins une marge), la même touche la referme. Un seul exécutable Rust, rien d'autre à installer.

Touche par défaut : **`Ctrl+Alt+W`**.

## Installer

Ouvre **PowerShell** et colle :

```powershell
powershell -c "irm https://github.com/enixCode/quickref/releases/latest/download/quickref-installer.ps1 | iex"
```

Puis lance la barre une fois :

```powershell
quickref
```

C'est tout. Il démarre, s'ajoute au démarrage de Windows, et se met à jour tout seul. Appuie sur **`Ctrl+Alt+W`** pour ouvrir / fermer (Échap ou un clic ferment aussi).

### Laisser un agent IA le faire

Tu utilises un agent de code (Claude Code, Cursor...) ? Ouvre **[AGENT-SETUP.md](AGENT-SETUP.md)**, copie le bloc dedans et colle-le à ton agent : il installe quickref, **te demande tes outils et raccourcis**, configure ta grille (et la synchro de ton `keybindings.json` VSCode), et vérifie que tout tourne.

## Configuration

Tous tes réglages sont dans **un seul fichier** : `%APPDATA%\quickref\config.json` (grille, couleurs, police, marge, **sources dynamiques**). Modifie, enregistre, puis relance quickref.

Format complet et fonctionnement interne : **[AGENT-SETUP.md](AGENT-SETUP.md)**.

## Mettre à jour / Désinstaller

**Mise à jour** : automatique, au démarrage.

**Désinstaller** :

```powershell
irm https://raw.githubusercontent.com/enixCode/quickref/main/uninstall.ps1 | iex
```

## Pour les développeurs

```powershell
cargo build --release      # ajoute -j 1 si peu de RAM
```

Binaire dans `target/release/quickref.exe`. **Mode dev** : `quickref --dev` cohabite avec ta version installée (accent orange + repère « MODE DEV », pas d'autostart ni d'update).

Distribution gérée par **[dist](https://opensource.axo.dev/cargo-dist/)** (`dist-workspace.toml` + `.github/workflows/release.yml`) : pousser un tag `vX.Y.Z` déclenche le build dans le cloud et publie la Release (binaire + installeur + updater).

## Licence

MIT. Voir [LICENSE](LICENSE).
