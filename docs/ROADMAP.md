# Roadmap Greenhouse Idle

Fichier vivant — coche, ajoute, réordonne librement.  
Spec détaillée auto : [`automation.md`](automation.md)

Légende : `[ ]` à faire · `[~]` en cours · `[x]` fait · `[?]` idée / à trancher

---

## Fait

- [x] Boucle core (planter, clic pousse, récolte, commandes, combo)
- [x] Boutique boosts (speed, click, yield, plots)
- [x] Arbre de compétences (combo / XP / commandes / or)
- [x] Prestige + draft reliques
- [x] Vente directe + modal
- [x] Onglet Missions (daily / weekly / carrière)
- [x] Spec automatisation + édition terrain (`docs/automation.md`)

---

## Prochain step — Automatisation & terrain

Spec : `docs/automation.md`

### A. Fondations grille

- [ ] Grille fixe 10×10 (remplacer packing `sqrt(n)`)
- [ ] Jetons terre (achat boutique = +1 jeton à placer)
- [ ] Bump version save — ignorer anciennes saves
- [ ] Save / load : coords terres + stocks

### B. Modal édition terrain

- [ ] Bouton Éditer dès 1ʳᵉ terre achetée
- [ ] Warning pertes cultures → clear cultures + `auto_plant_id`
- [ ] Modal plein (bloque le reste du jeu)
- [ ] Placement libre : terre / machines (min 1 terre pour machines)
- [ ] Message d’aide si machine sélectionnée sans terre
- [ ] Reset complet (rend tout au stock, style CoC)
- [ ] Annuler (restore layout d’avant ouverture) + Valider
- [ ] Compteurs `X/X` (terres, ferti, jardiniers)
- [ ] Tuto première ouverture édition
- [ ] Overlays range en édition seulement (vert ferti / jaune jardinier / split)
- [ ] Zoom édition — plus tard si besoin

### C. Machines

- [ ] Boutique 3 lignes P1 / P3 / P5 (plus teasers P6/P10 séparés)
- [ ] Fertiliseur : aérien, range centre exclu, accélération pousse
- [ ] Jardinier : occupe plot, 1 récolte+replante / 2 s, dernier légume
- [ ] Livreur : instantané si stock OK, max 1
- [ ] Prestige : reset machines + layout
- [ ] % exact accélération fertiliseur — à balancer `[?]`

### D. Arbre Atelier

- [ ] Rouages (−12 % coût machines)
- [ ] Bras longs / Tournée large / Chaîne vive / Réseau

---

## Ensuite (hors auto)

- [ ] SFX
- [ ] Progression offline
- [ ] i18n FR / EN
- [ ] 

---

## Idées parking

Ajoute ici dès que ça te passe par la tête (pas priorisé).

- [ ] 
- [ ] 
- [ ] 

---

## Notes perso

> Espace libre pour décisions, liens, captures…

-
