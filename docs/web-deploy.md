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
   Le workflow **écrase toujours** `index.html` avec `crops_express_idle.html` (évite une vieille version PWA).  
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
- SW **network-first** pour HTML/JS (`tools/patch_web_sw.py`)
- **Hard refresh auto** si le chargement dépasse ~20 s (purge caches + reload)
- Détection de **nouveau build** (`fileSizes`) → invalidation cache

### Téléphone toujours en ancienne version ?

Le service worker Godot met le jeu en cache (PWA). Après un déploiement :

- **Safari iOS** : Réglages → Safari → Effacer historique et données du site (ou ouvrir le lien en onglet privé une fois), puis ré-ajouter à l’écran d’accueil.
- **Chrome Android** : menu du site → Infos sur le site → Stockage → Effacer / Désinstaller l’appli web, puis recharger [le site](https://mandogo.github.io/farming-game/).
- Ou ouvrir : `https://mandogo.github.io/farming-game/?v=` + date du jour pour forcer un refresh.

## Mobile

- Bandeaux noirs : ratio 16:9 figé → corrigé avec stretch **expand** (remplit l’écran).
- Barre d’URL du navigateur : **impossible** à masquer en navigation web classique.
- Meilleure UX téléphone : **Ajouter à l’écran d’accueil** (PWA) → ouverture sans barre d’URL.
- Shell HTML : `misc/web/shell.html` (`100dvh`, safe-area, tip mobile).

## Rappel

Modifier un PNG dans `assets/` ne met **pas** à jour le site : il faut **ré-exporter** puis push `web_export/` (le `.pck`).
