# Automatisation — décisions design

Spec validée (conversation cloud, 2026-08). À suivre pour l’implémentation et les prochains prompts.

## État actuel

- Teasers boutique P1 / P3 / P6 / P10 (non achetable).
- Assets UI : `fertilizer`, `auto_planter`, `auto_harvester`, `auto_delivery`.
- Champs préparatoires : `auto_plant_id` sur plot ; relique `machine_oil` (coût boutique active, puissance machines = stub).
- Gameplay placement / effets : **pas encore**.

## Principes communs

- Machines **achetables en plusieurs exemplaires** en boutique (prix cher, courbe exponentielle).
- **Portée** part de **1** (voisinage Chebyshev : range 1 ≈ 3×3 centré sur l’ancre), augmente via upgrades (niveau machine + / ou nœuds arbre de compétences).
- Zones qui se chevauchent = OK.
- **1 machine du même type par parcelle-ancre**.

---

## 1. Fertiliseur (robot aérien)

| | |
|---|---|
| **Rôle** | Accélère la pousse dans sa zone (passif). |
| **Débloc** | Tôt (teaser actuel P1). |
| **Placement** | Ancré sur une parcelle ; sprite **au-dessus du centre** (bras / drone suspendu). |
| **Portée** | Départ range 1, upgradeable. |
| **Quantité** | Plusieurs en boutique, chers. |
| **Upgrades** | Puissance (% vitesse) via niveau machine ; portée via arbre / upgrades. |

Ne **occupe pas** une case cultivable (surplombe seulement).

---

## 2. Jardinier (plante + récolte fusionnés)

Planteur et récolteuse **ne sont pas deux machines séparées** : une seule unité « Jardinier ».

| | |
|---|---|
| **Rôle** | Sur les cases **PRÊTES** dans sa zone : récolte → stock, puis **replante**. |
| **Débloc** | Plus tard / plus cher que le fertiliseur (ex. ex-P3). |
| **Placement** | **Occupe un plot de terre** (contrepartie : une case en moins cultivable). Sprite **au sol** (bot roues / chenilles), pas superposé au fertiliseur aérien. |
| **Portée** | Même principe que le fertiliseur : départ range 1, upgradeable. |
| **Quantité** | Plusieurs en boutique, encore plus chers. |
| **UI** | Ferti = air/centre ; jardinier = sol/plot occupé → silhouettes distinctes. Portée en fantôme (couleurs différentes). |

### Replante

- Replante le **dernier légume présent sur cette case** (`auto_plant_id` local au plot).
- Mis à jour à chaque plantation (manuelle ou auto).
- **Pas** de panneau de config de graine au placement.
- Pour changer de culture : planter une fois à la main sur la case.
- Si `auto_plant_id` vide : récolte seulement (ou ignore jusqu’à une première plantation).

---

## 3. Livreur auto (plus tard)

- Hors scope immédiat.
- Automatise les **commandes clients** (autre système que les plots).
- Teaser boutique actuel P10.

---

## Découpage produit

| Machine | Job | Priorité |
|--------|-----|----------|
| Fertiliseur | *plus vite* | 1 — première à implémenter |
| Jardinier | *sans clic sur les parcelles* | 2 |
| Livreur | *sans clic sur les commandes* | 3 |

## Notes techniques existantes

- `GameState` plots : `auto_plant_id` déjà écrit à la plantation / save.
- `harvest_all_ready()` défini mais non branché.
- `machine_oil_power_mult()` stub (+10 %/niv) prévu pour rayon / efficacité machines.
- Ancien `has_sprinkler` : migration save qui ignore les cases sprinkler.
