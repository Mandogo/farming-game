# Greenhouse Idle

Idle farming 2D — commandes clients, or, XP, skills, combo livraisons, prestige, reliques.

## Lancer le jeu

1. Installe / ouvre **Godot 4.4+**
2. **Import** → dossier `greenhouse-idle`
3. Appuie sur **F5** (Play)

```powershell
& "..\tools\Godot_v4.4.1-stable_win64.exe" --path .
```

## Boucle actuelle

1. Clique une parcelle vide pour **planter** (gratuit)
2. Clique la pousse pour **accélérer** (1 clic = 1 tick, pas de hold)
3. Clique **PRÊT** pour **récolter** → stock
4. **Livre** les commandes → or + XP
5. Enchaîne des **combos de livraisons** → boost de pousse temporaire
6. Dépense l’or en **boutique**, les PC dans l’**arbre de compétences**
7. Atteins le niveau requis → **Prestige** → points pour reliques

## Prochaines features

- ~~Vente directe (bouton Sell + modal)~~
- ~~Onglet Missions (daily / weekly / carrière)~~
- ~~UX prestige (confirmation)~~
- ~~Courbe 1er prestige ≈ 30 min~~
- Draft reliques (3 choix, ~10) — **fait** (upgrade pts, cap niv.5)
- Automatisation (machines) — teasers boutique (P1/3/6/10), placement terrain = prochaine feature
- SFX, offline, i18n FR/EN — roadmap

## Structure

- `scripts/autoloads/game_state.gd` — logique métier
- `scripts/main.gd` — UI principale
- `scripts/ui/` — modals (sell, prestige) + panel missions
- `scripts/iso_block_builder.gd` — blocs iso
- `scenes/main.tscn` — scène principale
- `scripts/data/` — CropData, MissionData
- `assets/textures/` — voir `assets/textures/TEXTURES.txt`

Doc design : `../Greenhouse-Idle-GDD.md`
