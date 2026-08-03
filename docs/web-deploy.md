# Jouer en ligne (GitHub Pages)

URL : **https://mandogo.github.io/farming-game/**

Le jeu est dans `docs/` ; un workflow GitHub Actions le publie.

## À faire maintenant (repo déjà public)

1. **Commit + push** sur `main` :
   - le dossier `docs/` (avec `index.html`, `.wasm`, `.pck`, etc.)
   - `.github/workflows/deploy-pages.yml`
2. Sur **https://github.com/Mandogo/farming-game/settings/pages** :
   - **Source** = **GitHub Actions** (déjà le cas chez toi)
   - **Ne clique pas** sur « GitHub Pages Jekyll »
   - **Custom domain** : laisse **vide**
3. Onglet **Actions** du repo → lance / attends **Deploy GitHub Pages** (vert).
4. Reviens dans **Settings → Pages** : tu dois voir *Your site is live at https://mandogo.github.io/farming-game/*

Si le workflow n’apparaît pas : **Actions** → **Deploy GitHub Pages** → **Run workflow**.

## Mises à jour

```text
Godot → Export Web → docs/crops_express_idle.html
Copy-Item -Force docs\crops_express_idle.html docs\index.html
git add docs ; git commit ; git push
```

## Variante sans Actions (optionnelle)

Dans Settings → Pages, si le menu **Source** propose **Deploy from a branch** :
Branch `main`, folder `/docs`, Save. Même URL.
