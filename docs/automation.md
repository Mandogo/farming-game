# Automatisation — décisions design

## Pivot fun (2026-08)

**Critique** : « range++ / multi-achat / AFK » enlève des clics mais n’ajoute pas de fun.

**Nouveau principe** : une automatisation doit créer un **verbe**, un **timing**, ou un **build** — pas seulement supprimer une action.

| Anti-pattern | Pattern fun |
|--------------|-------------|
| Passif invisible | Pulse / charge / fenêtre que tu déclenches |
| Même effet × N robots | Spécialistes avec tradeoffs |
| Remplace le joueur | Amplifie un pic (combo, rush, monoculture) |
| Upgrade plat (range, %) | Choix de style de serre |

Les choix spatiaux ci-dessous restent une base UI ; le **comportement** doit être revalidé avant code.

---

## État code actuel

- Teasers boutique P1 / P3 / P6 / P10 (non achetable).
- Assets UI : `fertilizer`, `auto_planter`, `auto_harvester`, `auto_delivery`.
- Champs préparatoires : `auto_plant_id` sur plot ; relique `machine_oil` (coût boutique active, puissance = stub).
- Gameplay placement / effets : **pas encore**.

---

## Base spatiale (gardée, UI)

Toujours utile même avec le pivot fun :

- **Fertiliseur** : robot **aérien**, ancré sur une parcelle, **n’occupe pas** la case cultivable.
- **Jardinier** (= planteur + récolte fusionnés) : **occupe un plot** ; sprite **au sol** (pas superposé au ferti).
- Replante = **dernier légume de la case** (`auto_plant_id`), pas de panneau graine.
- Portée de départ 1 ; 1 machine du même type par ancre.
- Livreur = autre système (commandes), plus tard.

---

## Direction fun proposée (à valider)

### 1. Fertiliseur → « Pulse nutritif »

- Charge lente en fond (ou via tes clics de pousse dans la zone).
- **Clic sur le robot** = onde de croissance dans la portée (cooldown).
- Pendant **Frénésie combo** : pulse gratuit / plus fort → tu sync ferti + livraisons.
- Fun = timing + juice, pas un +% invisible.

### 2. Jardinier → « Contremaître de culture »

- Occupe un plot, range 1+.
- **Bonus fort en monoculture** dans sa zone (même légume) ; zone mixte = lent / malus léger.
- Travaille par **tournée** : enchaîne récolte→replante, puis petite pause (ou besoin d’un tap « go » hors frénésie).
- En frénésie : tournées accélérées (spectacle).
- Fun = tu shapes ta serre pour lui ; ce n’est pas un dumb autofarm.

### 3. Livreur → « Client favori » (pas full-AFK)

- Tu **épingles** 1 type de commande / client : il ne livre que ça, très bien.
- Full auto toutes commandes = trop fort / trop fade ; garder le juggling pour le joueur.
- Fun = build autour d’une demande, pas « gagne sans regarder ».

### 4. Pic partagé : Rush serre

- Bouton / événement : beaucoup de commandes + machines en surrégime, timer court.
- Les autos deviennent **jouissives** parce qu’elles explosent dans une fenêtre, pas 24/7.

---

## Idées à fort potentiel fun (non validées)

| Idée | Verbe joueur | Pourquoi c’est plus fun |
|------|--------------|-------------------------|
| **Station de prep** | Compose 2–3 légumes → « plat » qui match une commande difficile | Mini craft, sink stock, décisions |
| **Abeille / pollinisateur** | Guide ou attire une unité qui lie 2 parcelles | Émergent, lisible, mignon |
| **Climats de serre** | Bascule tropique / tempéré / sec (buffs cultures) | Build identity, pas un robot de plus |
| **Contre-ordre / rush clients** | Déclenche une vague de commandes | Overload contrôlé, pic de stress/fun |
| **Mentor robot** | XP / or sur les actions que **tu** fais dans sa zone | Amplifie le skill expressif, ne le remplace pas |

À éviter tant que le fun n’est pas prouvé : multi-achat exponentiel de clones passifs, upgrades « +1 range » comme seul levier, amplificateur de combo 100 % passif.

---

## Découpage produit (provisoire)

1. Valider le pivot (pulse / monoculture / client favori / rush) ou une variante.
2. Prototyper **une** machine fun (ferti-pulse ou jardinier-monoculture) avant d’élargir la boutique.
3. Livreur / autres candidatures ensuite.

## Notes techniques

- `auto_plant_id` déjà écrit à la plantation / save.
- `harvest_all_ready()` défini mais non branché.
- `machine_oil_power_mult()` stub — à redéfinir selon le pivot (ex. charge / cooldown pulse).
