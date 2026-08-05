# Roadmap Crops Express Idle

Fichier vivant — coche, ajoute, réordonne librement.  
Spec détaillée auto : [`automation.md`](automation.md)

**Nom Steam / produit :** Crops Express Idle (ex-Greenhouse Idle) — idle + commandes/livraison ; auto hors titre.

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
- [x] Grille fixe 10×10 + jetons terre (achat = stock, placement en édition)
- [x] Save v8 (ignore anciennes saves) + coords terres / machines
- [x] Modal édition terrain (grille 2D, outils colorés, reset CoC, annuler/valider, compteurs, overlays, tuto — sans warning d’entrée)
- [x] Boutique machines P1 / P3 / P5 (Fertiliseur, Jardinier, Livreur)
- [x] Fertiliseur gameplay (×1,5 pousse, range centre exclu)
- [x] Jardinier gameplay (2 s, récolte+replante, `auto_plant_id`)
- [x] Livreur instantané (max 1)
- [x] Prestige : reset machines + layout
- [x] Branche Atelier (Rouages / Bras longs / Tournée / Chaîne / Réseau)

---

## Prochain step — Automatisation & terrain

Spec : `docs/automation.md`

### A. Fondations grille

- [x] Grille fixe 10×10 (remplacer packing `sqrt(n)`)
- [x] Jetons terre (achat boutique = +1 jeton à placer)
- [x] Bump version save — ignorer anciennes saves
- [x] Save / load : coords terres + stocks

### B. Modal édition terrain

- [x] Bouton Éditer dès le 1er achat de terre (pas au lancement)
- [x] Achat parcelle = placement auto adjacent + réorga libre via Éditer
- [x] Warning pertes cultures → clear cultures + `auto_plant_id`
- [x] Modal édition = panneau centré + jetons-icônes (terre / ferti / jardinier / retirer)
- [x] Placement libre : terre / machines (min 1 terre pour machines)
- [x] Message d’aide si machine sélectionnée sans terre
- [x] Reset complet (rend tout au stock, style CoC)
- [x] Annuler (restore layout d’avant ouverture) + Valider
- [x] Compteurs `X/X` (terres, ferti, jardiniers)
- [x] Tuto première ouverture édition (à l’achat 1ʳᵉ parcelle + doigt sur Éditer)
- [x] Grille édition invisible hors modal (cases vides cachées + cadrage sur terres)
- [x] Overlays range en édition seulement (vert ferti / jaune jardinier / split)
- [ ] Zoom édition — plus tard si besoin

### C. Machines

- [x] Boutique 3 lignes P1 / P3 / P5 (plus teasers P6/P10 séparés)
- [x] Fertiliseur : aérien, range centre exclu, accélération pousse
- [x] Jardinier : occupe plot, 1 récolte+replante / 2 s, dernier légume
- [x] Livreur : instantané si stock OK, max 1
- [x] Prestige : reset machines + layout
- [?] % exact accélération fertiliseur — **×1,5** en v1 (à balancer en playtest)

### D. Arbre Atelier

- [x] Rouages (−12 % coût machines)
- [x] Bras longs / Tournée large / Chaîne vive / Réseau

---

## Ensuite (hors auto)

- [ ] SFX
- [ ] Progression offline
- [ ] i18n FR / EN
- [ ] 

---

## Idées parking

Ajoute ici dès que ça te passe par la tête (pas priorisé).

- [ ] Zoom édition terrain (si cases trop petites)
- [x] Feedback VFX sur tournée jardinier / pulse fertiliseur
- [ ] 

---

## Notes perso

> Espace libre pour décisions, liens, captures…

- **Branding :** Crops Express Idle — icône camion teal + caisse légumes + pièces (`icon.png` fenêtre / Steam, `assets/textures/ui/logo.png` UI).
- Fertiliseur v1 : hover vertical + salve / **2 s** (8 cases autour, **−0,5 s**) ; ombre sol + contour blanc ; cercle de portée à la pose
- Save : `SAVE_VERSION = 8` — drop des saves pré-grille
-
