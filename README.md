# Greenhouse Idle

Idle farming 2D — commandes clients, or, XP, skills, combo livraisons, prestige, reliques.

## Lancer le jeu

1. Installe / ouvre **Godot 4.4+**
2. **Import** → ce dossier
3. **F5** (Play)

```powershell
& "..\tools\Godot_v4.4.1-stable_win64.exe" --path .
```

## Docs

| Fichier | Rôle |
|--------|------|
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | **Roadmap vivante** — coche / ajoute tes idées |
| [`docs/automation.md`](docs/automation.md) | Spec automatisation + édition terrain |
| [`assets/textures/TEXTURES.txt`](assets/textures/TEXTURES.txt) | Organisation des textures + scripts utiles |

## Boucle actuelle

1. Clique une parcelle vide pour **planter** (gratuit)
2. Clique la pousse pour **accélérer** (1 clic = 1 tick)
3. Clique **PRÊT** pour **récolter** → stock
4. **Livre** les commandes → or + XP
5. Combos de livraisons → boost de pousse temporaire
6. Or en **boutique**, PC dans l’**arbre**, prestige → **reliques**

## Structure du repo

```
assets/textures/   backgrounds, blocks, crops, icons, ui
docs/              ROADMAP + specs
scenes/            main.tscn, plot_tile.tscn
scripts/
  autoloads/       game_state.gd
  data/            CropData, MissionData
  ui/              modals & panels
  *.gd             main, plot_tile, iso, theme…
tools/             scripts Python art encore utiles (4)
```

Pas de cache Godot / `__pycache__` versionnés (voir `.gitignore`).
