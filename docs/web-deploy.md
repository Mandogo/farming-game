# Jouer en ligne (GitHub Pages)

Le dossier `web_export/` contient l’export Web Godot. La pipeline
[`.github/workflows/deploy-web.yml`](../.github/workflows/deploy-web.yml)
le publie automatiquement sur **GitHub Pages**.

URL prévue (après activation) :

**https://mandogo.github.io/farming-game/**

## Première mise en ligne (une seule fois)

1. **Commit + push** le dossier `web_export/` et le workflow sur `main`  
   (fichiers `.html`, `.js`, `.wasm`, `.pck`, images — pas besoin des `.import`).

2. Sur GitHub → ton repo → **Settings** → **Pages**  
   - **Source** : *GitHub Actions* (pas « Deploy from a branch »).

3. Onglet **Actions** : attends le workflow **Deploy Web (GitHub Pages)** (vert).

4. Ouvre l’URL ci-dessus. Au premier chargement, le `.wasm` (~37 Mo) peut prendre un moment.

## Mises à jour suivantes

1. Dans Godot : **Project → Export → Web** → ré-exporte dans `web_export/`
   (garde **Thread Support** = off — déjà le cas dans `export_presets.cfg`).
2. Commit / push `web_export/`.
3. Le workflow redéploie tout seul.

Tu peux aussi lancer un déploiement manuel : **Actions** → **Deploy Web** → **Run workflow**.

## Points importants

| Sujet | Détail |
|--------|--------|
| Threads | Export **sans** threads → pas besoin des headers COOP/COEP (GitHub Pages ne les fournit pas). |
| Repo privé | Pages sur compte gratuit = repo **public**, ou plan payant. |
| Cache navigateur | Après un redeploy, un hard refresh (Ctrl+F5) si l’ancienne version reste. |
| Taille | Le `.wasm` est gros : normal ; GitHub accepte jusqu’à 100 Mo / fichier. |

## Dépannage rapide

- **404** : Pages pas encore activé en source « GitHub Actions », ou workflow pas passé.
- **SharedArrayBuffer / threads** : tu as ré-exporté avec threads — décoche Thread Support et ré-exporte.
- **Écran noir / erreurs** : ouvre la console (F12) ; vérifie que `crops_express_idle.pck` et `.wasm` sont bien dans le dépôt.
