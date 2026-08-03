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

## Mobile

- Bandeaux noirs : ratio 16:9 figé → corrigé avec stretch **expand** (remplit l’écran).
- Barre d’URL du navigateur : **impossible** à masquer en navigation web classique.
- Meilleure UX téléphone : **Ajouter à l’écran d’accueil** (PWA) → ouverture sans barre d’URL.
- Shell HTML : `misc/web/shell.html` (`100dvh`, safe-area, tip mobile).

## Rappel

Modifier un PNG dans `assets/` ne met **pas** à jour le site : il faut **ré-exporter** puis push `web_export/` (le `.pck`).
