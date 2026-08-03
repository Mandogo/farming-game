# Jouer en ligne (GitHub Pages)

L’export Web vit dans **`web_export/`** (pas dans `docs/`).

URL : **https://mandogo.github.io/farming-game/**

## Déploiement

1. Godot → **Export → Web** → `web_export/crops_express_idle.html`
2. Puis :
   ```powershell
   Copy-Item -Force web_export\crops_express_idle.html web_export\index.html
   ```
3. Commit + push `web_export/` → le workflow **Deploy GitHub Pages** publie le site.

Settings → Pages → Source = **GitHub Actions**. Custom domain = vide.

## Rappel

Modifier un PNG dans `assets/` ne met **pas** à jour le site : il faut **ré-exporter** puis push `web_export/` (le `.pck`).
