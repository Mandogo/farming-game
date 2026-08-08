#!/usr/bin/env python3
"""Patch le service worker Godot + stamp le HTML après export Web.

Problème : le SW Godot est cache-first. Sans patch, une PWA (iPhone « Sur
l’écran d’accueil ») garde l’ancien HTML/JS indéfiniment — même après un
déploiement Pages réussi. Les changements shell-only ne touchent pas
fileSizes → l’ancien BUILD_ID ne détectait rien.

Ce script :
- force un CACHE_VERSION unique (hash wasm/pck/js/html)
- skipWaiting à l’install + clients.claim + reload des fenêtres à l’activate
- navigations + .html/.js en network-first
- stamp CEI_DEPLOY_ID dans les HTML (détecte les updates shell-only)
- synchronise index.html ← crops_express_idle.html
"""
from __future__ import annotations

import hashlib
import re
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "web_export"
SW_PATH = WEB / "crops_express_idle.service.worker.js"
HTML_MAIN = WEB / "crops_express_idle.html"
HTML_INDEX = WEB / "index.html"
JS_PATH = WEB / "crops_express_idle.js"


def _file_token(*names: str) -> str:
	h = hashlib.sha1()
	for name in names:
		p = WEB / name
		if p.exists():
			h.update(p.name.encode())
			h.update(str(p.stat().st_size).encode())
			h.update(p.read_bytes()[:65536])
			# Inclut aussi la fin (shell JS souvent en bas du HTML).
			data = p.read_bytes()
			if len(data) > 65536:
				h.update(data[-65536:])
	return h.hexdigest()[:12]


def _deploy_id() -> str:
	token = _file_token(
		"crops_express_idle.wasm",
		"crops_express_idle.pck",
		"crops_express_idle.js",
		"crops_express_idle.html",
		"crops_express_idle.service.worker.js",
	)
	return f"{int(time.time())}|{token}"


def _patch_sw(version: str) -> None:
	if not SW_PATH.exists():
		raise SystemExit(f"Missing {SW_PATH}")

	text = SW_PATH.read_text(encoding="utf-8")

	text2, n = re.subn(
		r"const CACHE_VERSION = '[^']*';",
		f"const CACHE_VERSION = '{version}';",
		text,
		count=1,
	)
	if n != 1:
		raise SystemExit("Failed to set CACHE_VERSION")
	text = text2

	# CACHED_FILES : inclure index.html pour les navigations /
	if '"index.html"' not in text:
		text = text.replace(
			'const CACHED_FILES = ["crops_express_idle.html"',
			'const CACHED_FILES = ["index.html","crops_express_idle.html"',
			1,
		)

	install_block = """self.addEventListener('install', (event) => {
	self.skipWaiting();
	event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));
});"""

	text2, n = re.subn(
		r"self\.addEventListener\('install',\s*\(event\)\s*=>\s*\{[\s\S]*?\n\}\);",
		install_block,
		text,
		count=1,
	)
	if n != 1:
		raise SystemExit("Failed to patch install handler")
	text = text2

	activate_block = """self.addEventListener('activate', (event) => {
	event.waitUntil(caches.keys().then(
		function (keys) {
			// Remove old caches. Only notify clients when this is a real update
			// (old cache present) — otherwise first install + claim reloads forever.
			var oldKeys = keys.filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME);
			var isUpdate = oldKeys.length > 0;
			return Promise.all(oldKeys.map((key) => caches.delete(key))).then(function () {
				return isUpdate;
			});
		}
	).then(function (isUpdate) {
		// Enable navigation preload if available.
		var preload = ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();
		return preload.then(function () { return isUpdate; });
	}).then(function (isUpdate) {
		return self.clients.claim().then(function () { return isUpdate; });
	}).then(function (isUpdate) {
		if (!isUpdate) return;
		// Vraie mise à jour : prévenir la page (elle hard-refresh si deploy_id diffère).
		return self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (all) {
			return Promise.all(all.map(function (c) {
				try { c.postMessage({ type: 'cei-reload', v: CACHE_VERSION }); } catch (e1) {}
			}));
		});
	}));
});"""

	text2, n = re.subn(
		r"self\.addEventListener\('activate',\s*\(event\)\s*=>\s*\{[\s\S]*?\n\}\);",
		activate_block,
		text,
		count=1,
	)
	if n != 1:
		raise SystemExit("Failed to patch activate handler")
	text = text2

	new_fetch = r'''self.addEventListener(
	'fetch',
	/**
	 * Triggered on fetch
	 * @param {FetchEvent} event
	 */
	(event) => {
		const isNavigate = event.request.mode === 'navigate';
		const url = event.request.url || '';
		const referrer = event.request.referrer || '';
		const base = referrer.slice(0, referrer.lastIndexOf('/') + 1);
		const local = url.startsWith(base) ? url.replace(base, '') : '';
		const pathName = (() => {
			try { return new URL(url).pathname.split('/').pop() || ''; } catch (e) { return local; }
		})();
		const isHtmlOrJs = /\.(html|js)$/i.test(pathName) || pathName === '' || pathName === 'index.html';
		const isHeavyAsset = /\.(wasm|pck)$/i.test(pathName);
		const isVersionProbe = pathName === 'cei-version.json';
		const isSwFile = /service\.worker\.js$/i.test(pathName);
		const isCacheable = FULL_CACHE.some((v) => v === local || v === pathName) || (base === referrer && base.endsWith(CACHED_FILES[0]));

		// Version + SW : jamais depuis Cache API (sinon PWA iOS reste coincée).
		if (isVersionProbe || isSwFile) {
			event.respondWith((async () => {
				let response = await fetch(event.request, { cache: 'no-store' });
				if (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
					response = ensureCrossOriginIsolationHeaders(response);
				}
				return response;
			})());
			return;
		}

		// Navigations + HTML/JS : network-first (évite HTML neuf + JS/WASM vieux).
		if (isNavigate || isHtmlOrJs) {
			event.respondWith((async () => {
				const cache = await caches.open(CACHE_NAME);
				try {
					const response = await fetchAndCache(event, cache, true);
					return response;
				} catch (e) {
					let cached = await cache.match(event.request);
					if (cached == null && pathName) {
						cached = await cache.match(pathName);
					}
					if (cached == null) {
						cached = await cache.match('index.html');
					}
					if (cached == null) {
						cached = await cache.match(CACHED_FILES[0]);
					}
					if (cached == null) {
						cached = await caches.match(OFFLINE_URL);
					}
					if (cached != null && ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
						cached = ensureCrossOriginIsolationHeaders(cached);
					}
					if (cached != null) {
						return cached;
					}
					throw e;
				}
			})());
			return;
		}

		if (isCacheable || isHeavyAsset) {
			event.respondWith((async () => {
				const cache = await caches.open(CACHE_NAME);
				// wasm/pck : network-first avec fallback cache (évite PWA coincée sur un vieux build).
				if (isHeavyAsset) {
					try {
						const response = await fetchAndCache(event, cache, true);
						return response;
					} catch (e) {
						let cached = await cache.match(event.request);
						if (cached == null && pathName) {
							cached = await cache.match(pathName);
						}
						if (cached != null) {
							if (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
								cached = ensureCrossOriginIsolationHeaders(cached);
							}
							return cached;
						}
						throw e;
					}
				}
				let cached = await cache.match(event.request);
				if (cached != null) {
					if (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
						cached = ensureCrossOriginIsolationHeaders(cached);
					}
					event.waitUntil(fetchAndCache(event, cache, true).catch(() => undefined));
					return cached;
				}
				const response = await fetchAndCache(event, cache, true);
				return response;
			})());
			return;
		}

		if (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
			event.respondWith((async () => {
				let response = await fetch(event.request);
				response = ensureCrossOriginIsolationHeaders(response);
				return response;
			})());
		}
	}
);'''

	text2, n = re.subn(
		r"self\.addEventListener\(\s*'fetch'[\s\S]*?\n\);\n\nself\.addEventListener\('message'",
		new_fetch + "\n\nself.addEventListener('message'",
		text,
		count=1,
	)
	if n != 1:
		raise SystemExit("Failed to patch fetch handler in service worker")
	text = text2

	# Godot message 'update' faisait clients.navigate() → reload en boucle avec notre shell.
	message_block = """self.addEventListener('message', (event) => {
	// No cross origin
	if (event.origin !== self.origin) {
		return;
	}
	const id = event.source.id || '';
	const msg = event.data || '';
	// Ensure it's one of our clients.
	self.clients.get(id).then(function (client) {
		if (!client) {
			return; // Not a valid client.
		}
		if (msg === 'claim' || msg === 'update') {
			self.skipWaiting().then(() => self.clients.claim());
		} else if (msg === 'clear') {
			caches.delete(CACHE_NAME);
		}
	});
});
"""
	text2, n = re.subn(
		r"self\.addEventListener\('message',\s*\(event\)\s*=>\s*\{[\s\S]*?\n\}\);\s*$",
		message_block,
		text,
		count=1,
	)
	if n != 1:
		raise SystemExit("Failed to patch message handler in service worker")
	text = text2

	SW_PATH.write_text(text, encoding="utf-8")
	print(f"Patched {SW_PATH.name} CACHE_VERSION={version}")


def _stamp_html(deploy_id: str) -> None:
	"""Injecte/ maj CEI_DEPLOY_ID + BUILD_ID dans le HTML exporté."""
	if not HTML_MAIN.exists():
		raise SystemExit(f"Missing {HTML_MAIN}")

	text = HTML_MAIN.read_text(encoding="utf-8")

	if "const CEI_DEPLOY_ID" in text:
		text2, n = re.subn(
			r"const CEI_DEPLOY_ID = '[^']*';",
			f"const CEI_DEPLOY_ID = '{deploy_id}';",
			text,
			count=1,
		)
		if n != 1:
			raise SystemExit("Failed to stamp CEI_DEPLOY_ID")
		text = text2
	else:
		# Ancien HTML : injecte juste avant BUILD_ID ou loadStartedAt
		needle = "const loadStartedAt = performance.now();"
		if needle not in text:
			raise SystemExit("Cannot find injection point for CEI_DEPLOY_ID")
		text = text.replace(
			needle,
			"const loadStartedAt = performance.now();\n"
			f"\tconst CEI_DEPLOY_ID = '{deploy_id}';",
			1,
		)

	# BUILD_ID = deploy stamp + layout ver (si présent) + fileSizes
	if re.search(r"const BUILD_ID = ", text):
		build_expr = (
			"const BUILD_ID = String(CEI_DEPLOY_ID) + '|' + "
			"(typeof CEI_LAYOUT_VER !== 'undefined' ? CEI_LAYOUT_VER + '|' : '') + "
			"JSON.stringify((GODOT_CONFIG && GODOT_CONFIG.fileSizes) || {});"
		)
		text2, n = re.subn(
			r"const BUILD_ID = [^;]+;",
			build_expr,
			text,
			count=1,
		)
		if n != 1:
			raise SystemExit("Failed to stamp BUILD_ID")
		text = text2

	HTML_MAIN.write_text(text, encoding="utf-8")
	HTML_INDEX.write_text(text, encoding="utf-8")
	print(f"Stamped CEI_DEPLOY_ID={deploy_id} → {HTML_MAIN.name} + {HTML_INDEX.name}")


def _write_version_json(deploy_id: str) -> None:
	"""Fichier léger toujours network-only — permet à la PWA de détecter un nouveau build."""
	import json

	path = WEB / "cei-version.json"
	path.write_text(
		json.dumps(
			{
				"deploy_id": deploy_id,
				"ts": int(time.time()),
			},
			separators=(",", ":"),
		)
		+ "\n",
		encoding="utf-8",
	)
	print(f"Wrote {path.name} deploy_id={deploy_id}")


def _patch_godot_input() -> None:
	"""Remap clientX/Y via window.ceiScreenToCanvas (portrait CSS-rotaté).

	Godot mappe les événements via getBoundingClientRect AABB, ce qui casse
	quand #cei-game a rotate(90deg) — les clics ratent UI / parcelles.
	"""
	if not JS_PATH.exists():
		raise SystemExit(f"Missing {JS_PATH}")

	text = JS_PATH.read_text(encoding="utf-8")
	if "ceiScreenToCanvas" in text and "CEI_INPUT_PATCH" in text:
		print(f"Input patch already present in {JS_PATH.name}")
		return

	old = (
		"computePosition:function(evt,rect){"
		"const canvas=GodotConfig.canvas;"
		"const rw=canvas.width/rect.width;"
		"const rh=canvas.height/rect.height;"
		"const x=(evt.clientX-rect.x)*rw;"
		"const y=(evt.clientY-rect.y)*rh;"
		"return[x,y]}"
	)
	new = (
		"computePosition:function(evt,rect){"
		"/* CEI_INPUT_PATCH */"
		"if(typeof window!=='undefined'&&typeof window.ceiScreenToCanvas==='function'){"
		"const p=window.ceiScreenToCanvas(evt.clientX,evt.clientY);"
		"if(p&&p.length===2&&isFinite(p[0])&&isFinite(p[1]))return p;"
		"}"
		"const canvas=GodotConfig.canvas;"
		"const rw=canvas.width/rect.width;"
		"const rh=canvas.height/rect.height;"
		"const x=(evt.clientX-rect.x)*rw;"
		"const y=(evt.clientY-rect.y)*rh;"
		"return[x,y]}"
	)
	if old not in text:
		raise SystemExit("Failed to find GodotInput.computePosition for input patch")
	JS_PATH.write_text(text.replace(old, new, 1), encoding="utf-8")
	print(f"Patched GodotInput.computePosition in {JS_PATH.name}")


def patch() -> None:
	_patch_godot_input()
	deploy_id = _deploy_id()
	_patch_sw(deploy_id)
	_stamp_html(deploy_id)
	_write_version_json(deploy_id)


if __name__ == "__main__":
	patch()
