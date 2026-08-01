# Automatisation — décisions design

Spec validée (conversation cloud, 2026-08). Source de vérité pour l’implémentation.

## État code actuel

- Teasers boutique (non achetable) — à aligner sur P1 / P3 / P5 (3 machines).
- Assets UI : `fertilizer`, `auto_planter`, `auto_harvester`, `auto_delivery` (planteur+récolte → **Jardinier**).
- Champs préparatoires : `auto_plant_id` sur plot ; relique `machine_oil` (coût boutique active, puissance = stub).
- Gameplay placement / effets : **pas encore**.

## Principes communs

- **Pas d’upgrades boutique** pour les machines (ni puissance ni cadence en or).
- Progression machines via : **achat d’exemplaires** (or) + **portée / cadence dans l’arbre** (PC, reset prestige).
- Portée départ **1** (Chebyshev : range 1 ≈ 3×3).
- Zones qui se chevauchent = OK (overlay moitié-moitié, voir édition terrain).
- **1 machine du même type par parcelle-ancre**.
- Relique `machine_oil` : −3 % coûts boutique / niv (déjà en jeu) ; applicable aux achats machines.
- Terrain = **grille fixe 10×10** ; les terres et machines se placent en **mode édition** (plus de packing `sqrt(n)` auto).

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
→ 10ᵉ ≈ 40k · total ≈ **93k** (+ jusqu’à 10 plots sacrifiés)

---

## 1. Fertiliseur (robot aérien)

| | |
|---|---|
| **Rôle** | Accélère la pousse dans sa zone (passif). |
| **Placement** | Ancré sur une parcelle ; sprite **au-dessus du centre**. |
| **Portée** | Départ 1 ; + via arbre (Bras longs, Réseau). |
| **Plot** | N’occupe **pas** de case cultivable. |

---

## 2. Jardinier (plante + récolte fusionnés)

Une seule machine (plus de planteur / récolteuse séparés).

| | |
|---|---|
| **Rôle** | Cases **PRÊTES** dans la zone : récolte → stock → **replante**. |
| **Placement** | **Occupe un plot** ; sprite **au sol** (pas superposé au ferti). |
| **Portée** | Départ 1 ; + via arbre (Tournée large, Réseau). |
| **UI** | Ferti = air/centre ; jardinier = sol/plot. Fantômes de portée (couleurs distinctes). |

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
| **Rôle** | Livre les commandes clients automatiquement. |
| **Débloc** | Prestige **5**. |
| **Max** | **1** (pas de multi-achat). |
| **Terrain** | Pas de range / placement sur plots. |

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
| **Chaîne vive** | 2 | Rouages | Jardiniers −20 % délai tournée ; si livreur possédé, −15 % délai livraison |
| **Réseau** | 3 | Rouages | Capstone : **+1 portée** fertiliseurs **et** jardiniers |

Portée typique full spé : base 1 + nœud dédié + Réseau ≈ **3** (zone 7×7).

---

## Mode édition terrain (UI simple)

Enjeu majeur de la mise à jour : le joueur **optimise** la forme de ses champs avec les machines.

### Entrée

- Bouton **Éditer le terrain** (sur le champ).
- **Warning** obligatoire : les cultures en cours seront perdues.
- Confirm → **reset toutes les cultures** (plots vides) + reset des `auto_plant_id` (layout propre).
- Pendant l’édition : plus de planter / accélérer / récolter.
- **Pas de coût or** pour rearranger.
- Livreur : **hors** de ce flux (pas de placement terrain).

### Étape 1 — Placer la terre

- Outils simples : placer / déplacer / retirer la terre.
- Stock = jetons terre non placés (`unlocked_plots` − terres déjà posées).
- Achat boutique « parcelle » = +1 jeton à placer (plus déblocage séquentiel invisible).
- Machines **non proposées** tant que l’étape terre n’est pas validée (**Terre OK** / **Suivant**).
- Pas d’overlay de range à cette étape.

### Étape 2 — Placer les machines (si le joueur en possède)

- Uniquement si stock machines non placées > 0 (fertiliseurs et/ou jardiniers).
- Placement **uniquement sur une case terre**.
- Fertiliseur : ancre aérienne sur la terre (n’occupe pas la culture).
- Jardinier : occupe la case terre.
- Afficher la **portée actuelle** (base + skills) avec une **area colorée** sur les terres couvertes.

### Couleurs d’overlay

| Machine | Couleur |
|--------|---------|
| Fertiliseur | **Vert** |
| Jardinier | **Jaune** |

- Case couverte par **une** machine → teinte pleine (légère, lisible en iso).
- Case couverte par **les deux** → **moitié-moitié** (split sur la case ; vert | jaune).
- Couleur des ranges = couleur de la machine.
- L’icône robot reste sur l’ancre ; l’overlay colore le **sol couvert**.

### Sortie

- **Valider** → quitte l’édition, reprise du gameplay.
- Layout + ancres machines persistés pour la run (save).

---

## Découpage produit

| Élément | Priorité |
|--------|----------|
| Grille fixe + mode édition (terre) | 1 — prérequis spatial |
| Fertiliseur + overlay vert | 2 |
| Jardinier + overlay jaune / split | 3 |
| Livreur | 4 |
| Branche Atelier | avec ou juste après les machines terrain |

## Notes techniques

- Aujourd’hui le champ est packé en `sqrt(n)` iso (`main.gd` `_build_iso_field`) → à remplacer par grille 10×10 + cellules terre optionnelles.
- `auto_plant_id` déjà écrit à la plantation / save ; **vidé à l’entrée édition** (avec les cultures).
- `harvest_all_ready()` défini mais non branché.
- `machine_oil_power_mult()` stub — à redéfinir ou ignorer (pas d’upgrade boutique puissance).
- Teasers UI à passer de 4 lignes (P1/3/6/10) à 3 (P1/3/5) : Fertiliseur, Jardinier, Livreur.
