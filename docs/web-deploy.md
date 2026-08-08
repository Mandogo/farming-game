# Jouer en ligne (GitHub Pages)

L’export Web vit dans **`web_export/`** (pas dans `docs/`).

URL : **https://mandogo.github.io/farming-game/**

## Prérequis (une seule fois)

Sur GitHub → **Settings → Pages** :

1. **Build and deployment → Source** = **GitHub Actions** (pas “Deploy from a branch”)
2. Custom domain = vide
3. Enregistre

Sans ça, le workflow plante avec `Get Pages site failed / Not Found`.

## Déploiement

1. Godot → **Export → Web** → `web_export/crops_express_idle.html`
2. Puis :
   ```powershell
   python tools/patch_web_sw.py
   Copy-Item -Force web_export\crops_express_idle.html web_export\index.html
   ```
   (Linux/mac : `python3 tools/patch_web_sw.py && cp -f web_export/crops_express_idle.html web_export/index.html`)
3. Commit + push `web_export/` → le workflow **Deploy GitHub Pages** publie le site.  
   Le workflow **re-patche le SW** et stamp un `CEI_DEPLOY_ID` à chaque deploy (PWA auto-update : `skipWaiting` + `clients.claim` + reload).  
   Il **écrase toujours** `index.html` avec `crops_express_idle.html`.  
   Ou lance manuellement : Actions → Deploy GitHub Pages → Run workflow.

### Deploy Actions qui échoue ?

Causes fréquentes (ce n’est **pas** le contenu `web_export/`) :

1. **Re-run** du même workflow → 2 artefacts `github-pages` → erreur `Artifact count is 2`.  
   Correctif : purge des vieux artefacts + nom `github-pages-<attempt>`.
2. **File d’attente Pages** souvent > 10 min ; `actions/deploy-pages` **plafonne à 10 min** et peut annuler.  
   Correctif : déploiement OIDC + poll **45 min** (plus l’action officielle bornée).

Laisse le job `deploy` aller au bout. Un Re-run est OK maintenant (artefacts nettoyés).

### Navigateur bloqué à 92 % ?

Cause typique : **service worker** qui mélange HTML neuf + JS/WASM anciens.  
Correctifs en place :
- SW **network-first** pour HTML/JS (`tools/patch_web_sw.py`, rejoué à chaque deploy CI)
- `skipWaiting` + `clients.claim` + **reload auto** des fenêtres PWA à l’activate
- **Hard refresh auto** si le chargement dépasse ~20 s (purge caches + reload)
- Détection de **nouveau deploy** (`CEI_DEPLOY_ID` + `fileSizes`) → invalidation cache

### Téléphone toujours en ancienne version ?

Normalement **rien à faire** : à la réouverture / focus, le SW se met à jour et recharge.  
Si un vieux cache résiste encore :

- Fermer complètement l’app (swipe away) puis la rouvrir une fois
- Ou ouvrir : `https://mandogo.github.io/farming-game/?v=` + date du jour

## Mobile

- Le jeu est **toujours en paysage** : long côté = largeur, court = hauteur (même si le téléphone est vertical).
- En vertical : seul l’affichage est tourné (`rotate(90deg)`) — les mesures restent horizontales (évite l’ultra-stretch).
- Petites bandes noires latérales (~36 px) pour notch / Dynamic Island.
- Godot : `canvasResizePolicy = 0` + canvas dimensionné sur le cadre paysage (pas sur `window` portrait).
- Barre d’URL du navigateur : **impossible** à masquer en navigation web classique.
- Meilleure UX téléphone : **Ajouter à l’écran d’accueil** (PWA) → ouverture sans barre d’URL.
- Shell HTML : `misc/web/shell.html` (`100dvh`, safe-area, tip mobile).

## Rappel

Modifier un PNG dans `assets/` ne met **pas** à jour le site : il faut **ré-exporter** puis push `web_export/` (le `.pck`).
