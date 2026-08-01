# Automatisation — décisions design

Spec validée (conversation cloud, 2026-08). Source de vérité pour l’implémentation.

## État code actuel

- Teasers boutique (non achetable) — à aligner sur P1 / P3 / P5 (3 machines).
- Assets UI : `fertilizer`, `auto_planter`, `auto_harvester`, `auto_delivery` (planteur+récolte → **Jardinier**).
- Champs préparatoires : `auto_plant_id` sur plot ; relique `machine_oil` (coût boutique active, puissance = stub).
- Gameplay placement / effets / édition terrain : **pas encore**.

## Principes communs

- **Pas d’upgrades boutique** pour les machines (ni puissance ni cadence en or).
- Progression machines via : **achat d’exemplaires** (or) + **portée / cadence dans l’arbre** (PC, reset prestige).
- Portée **R** = anneau Chebyshev **centre exclu** : cases avec `0 < max(|dx|,|dy|) <= R`.  
  → Range 1 de base = **8 cases** autour (diagonales incluses).
- Zones qui se chevauchent = OK (overlay moitié-moitié, voir édition terrain).
- **1 machine du même type par case-ancre**.
- Relique `machine_oil` : −3 % coûts boutique / niv ; applicable aux achats machines.
- Terrain = **grille fixe 10×10** ; terres + machines placées en **mode édition** (plus de packing `sqrt(n)`).
- **Prestige** : machines possédées + layout machines **reset** (comme le reste de la run). Terres → `start_plots()` jetons (`deep_roots` inclus).
- **Saves** : pas de migration des anciennes saves (incompatibles) — **bump version / ignorer** l’ancien fichier. Nouvelle save = positions grille (terres) + ancres machines + stocks.

---

## Boutique

| Machine | Débloc | Prix 1er | Formule (n = déjà possédés) | Max |
|--------|--------|----------|-----------------------------|-----|
| **Fertiliseur** | Prestige **1** | **180** or | `180 × 1,70^n` | **10** |
| **Jardinier** | Prestige **3** | **260** or | `260 × 1,75^n` | **10** |
| **Livreur** | Prestige **5** | **2 400** or | — | **1** |

Cible design : 1er fertiliseur / jardinier ≈ **8–12 commandes** après le prestige qui les débloque ; ensuite montée rapide.

### Barème fertiliseurs (×1,70)

180 · 306 · 520 · 884 · 1 503 · 2 555 · 4 344 · 7 384 · 12 553 · 21 340  
→ 10ᵉ ≈ 21k · total ≈ **51k**

### Barème jardiniers (×1,75)

260 · 455 · 796 · 1 393 · 2 438 · 4 266 · 7 466 · 13 065 · 22 864 · 40 012  
→ 10ᵉ ≈ 40k · total ≈ **93k** (+ jusqu’à 10 plots jardiniers)

---

## 1. Fertiliseur (robot aérien)

| | |
|---|---|
| **Rôle** | Accélère la pousse sur les **terres dans sa portée** (passif, centre exclu). |
| **Placement** | Ancré sur une case **terre** ; sprite **au-dessus du centre**. |
| **Portée** | Départ 1 (= 8 voisins) ; + via arbre (Bras longs, Réseau). |
| **Plot** | N’occupe **pas** la case (toujours cultivable sous le robot). |

---

## 2. Jardinier (plante + récolte fusionnés)

Une seule machine (plus de planteur / récolteuse séparés).

| | |
|---|---|
| **Rôle** | Sur les terres **PRÊTES** dans sa portée : récolte → stock → **replante** (même tick). |
| **Cadence base** | **1 action (récolte+replante) toutes les 2,0 s** ; améliorable via **Chaîne vive**. |
| **Placement** | **Occupe** une case terre ; sprite **au sol**. |
| **Portée** | Départ 1 (= 8 voisins, **pas** sa propre case) ; + via arbre. |

### Replante

- Replante le **dernier légume de la case** (`auto_plant_id`).
- Mis à jour à chaque plantation (manuelle ou auto).
- Pas de panneau de config de graine.
- Changer de culture = planter une fois à la main sur la case.
- `auto_plant_id` vide → récolte seulement (ou ignore jusqu’à une 1ʳᵉ plantation).

---

## 3. Livreur auto

| | |
|---|---|
| **Rôle** | Livre **toutes** les commandes dès que le stock suffit. |
| **Débloc** | Prestige **5**. |
| **Max** | **1**. |
| **Délai** | **Aucun** — instantané dès que les ingrédients sont dispo. |
| **Terrain** | Pas de placement / range. |

---

## Arbre de compétences — branche **Atelier**

Nouvelle spé depuis le hub `Serre ouverte`. Coûts alignés sur les autres branches (2 / 2 / 3). Reset au prestige.

```
Serre ouverte (hub)
 └─ Rouages (2 PC)
      ├─ Bras longs (2)
      ├─ Tournée large (2)
      ├─ Chaîne vive (2)
      └─ Réseau (3)          ← capstone
```

| Nœud | PC | Parent | Effet |
|------|-----|--------|--------|
| **Rouages** | 2 | hub | Spé Machines : coûts **achat machines** −12 % |
| **Bras longs** | 2 | Rouages | Portée **fertiliseurs +1** |
| **Tournée large** | 2 | Rouages | Portée **jardiniers +1** |
| **Chaîne vive** | 2 | Rouages | Jardiniers : délai de tournée **−20 %** (base 2,0 s → 1,6 s) |
| **Réseau** | 3 | Rouages | Capstone : **+1 portée** fertiliseurs **et** jardiniers |

Portée typique full spé : base 1 + nœud dédié + Réseau ≈ **3** (anneau jusqu’à distance 3, centre exclu).

---

## Mode édition terrain (UI simple)

Enjeu majeur : optimiser la forme des champs avec les machines.

### Ouverture

- Bouton **Éditer** visible dès le **1er achat de terre** en boutique.
- **Tutoriel** déclenché à ce moment (comment placer terre / machines / valider / reset).
- Ouverture en **modal** : pas d’accès au reste du jeu (boutique, commandes, etc.) tant que le modal est ouvert.
- **Warning** : les cultures en cours seront perdues.
- Confirm → **reset toutes les cultures** + `auto_plant_id` vidés.
- **Pas de coût or** pour rearranger.
- Clics AoE / voisins : si trous dans le layout, c’est le choix du joueur (pas de correctif spécial).

### Contenu du modal (ordre libre)

Pas d’étapes forcées terre → machines. Le joueur place **dans l’ordre qu’il veut**.

- Outils : terre, fertiliseur, jardinier, déplacer, retirer.
- **Reset complet** (style Clash of Clans) : rend **tous** les jetons terre + **toutes** les machines au stock ; grille vide.
- Stock affiché : terres `placées/total`, machines `X/X` (ex. Fertiliseurs 2/4, Jardiniers 0/1).
- Machines **uniquement sur une case terre**.
- S’il sélectionne une machine alors qu’**aucune terre** n’est placée → petit message d’aide (ex. « Place d’abord une terre — les machines se posent sur la terre »).
- À l’ouverture (1ʳᵉ ou suivante) : partir du **terrain actuel** du joueur (terres + machines déjà posées).

### Overlays de portée (dans le modal)

| Machine | Couleur |
|--------|---------|
| Fertiliseur | **Vert** |
| Jardinier | **Jaune** |

- Affichés quand une machine est sélectionnée / survolée / posée, sur les **terres couvertes** (pas le centre ancre pour le calcul de range).
- Une couleur → teinte pleine légère.
- Les deux → **moitié-moitié** sur la case.
- **Hors édition** : pas d’overlay de range permanent — seules les icônes machines sur le terrain.

### Sortie

- **Valider** : applique le layout, ferme le modal. Autorisé même si machines encore en stock (compteurs `X/X` visibles).
- **Annuler** : ferme le modal, **restore** le layout d’avant ouverture (cultures déjà perdues après le warning d’entrée — le cancel ne les ramène pas).
- Layout + machines **persistés** dans la save de run.

### Tactile / mobile

- Chaque case de la grille 10×10 (même vide) doit être **touch-friendly** pour placer / cibler.
- Drag ou tap-tap selon ce qui est le plus simple en iso ; prioriser des cibles larges.

---

## Save / prestige

| Événement | Comportement |
|-----------|--------------|
| Save run | Grille (terres aux coords), machines (type + ancre), stocks non placés, compteurs achetés |
| Load ancienne save | Ignorer / invalider (bump version) — pas de migrateur |
| Prestige | Reset machines achetées + layout ; terres = `start_plots()` |

---

## Découpage produit

| Élément | Priorité |
|--------|----------|
| Grille 10×10 + modal édition (terre, reset, annuler/valider) | 1 |
| Tuto 1ʳᵉ terre + save positions | 1 |
| Fertiliseur + overlay vert | 2 |
| Jardinier (2 s) + overlay jaune / split | 3 |
| Branche Atelier | avec / juste après |
| Livreur instantané | 4 |

## Notes techniques

- Remplacer `_build_iso_field` packing `sqrt(n)` par grille fixe + cellules terre optionnelles.
- Bump `SAVE_VERSION` (ou équivalent) pour dropper les saves pré-grille.
- Teasers UI : 3 lignes P1/P3/P5 (Fertiliseur, Jardinier, Livreur).
