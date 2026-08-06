#!/usr/bin/env python3
"""Patch le service worker Godot après export Web.

Problème : cache-first sert un vieux .js/.wasm avec un HTML neuf → chargement
bloqué à 92 % dans le navigateur (la PWA a souvent un cache cohérent).

Ce script :
- force un CACHE_VERSION unique
- passe les navigations + .html/.js en network-first
- skipWaiting à l'install pour activer le nouveau SW tout de suite
"""
from __future__ import annotations

import hashlib
import re
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "web_export"
SW_PATH = WEB / "crops_express_idle.service.worker.js"


def _file_token(*names: str) -> str:
	h = hashlib.sha1()
	for name in names:
		p = WEB / name
		if p.exists():
			h.update(p.name.encode())
			h.update(str(p.stat().st_size).encode())
			h.update(p.read_bytes()[:65536])
	return h.hexdigest()[:10]


def patch() -> None:
	if not SW_PATH.exists():
		raise SystemExit(f"Missing {SW_PATH}")

	text = SW_PATH.read_text(encoding="utf-8")
	token = _file_token(
		"crops_express_idle.wasm",
		"crops_express_idle.pck",
		"crops_express_idle.js",
		"crops_express_idle.html",
	)
	version = f"{int(time.time())}|{token}"

	text = re.sub(
		r"const CACHE_VERSION = '[^']*';",
		f"const CACHE_VERSION = '{version}';",
		text,
		count=1,
	)

	# skipWaiting dès l'install
	if "self.skipWaiting()" not in text.split("addEventListener('install'")[1].split("addEventListener")[0]:
		text = text.replace(
			"self.addEventListener('install', (event) => {\n\tevent.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));\n});",
			"self.addEventListener('install', (event) => {\n\tself.skipWaiting();\n\tevent.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));\n});",
		)

	# clients.claim à l'activate
	if "self.clients.claim()" not in text:
		text = text.replace(
			").then(function () {\n\t\t// Enable navigation preload if available.\n\t\treturn ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();\n\t}));",
			").then(function () {\n\t\t// Enable navigation preload if available.\n\t\treturn ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();\n\t}).then(function () {\n\t\treturn self.clients.claim();\n\t}));",
		)

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
		const isCacheable = FULL_CACHE.some((v) => v === local || v === pathName) || (base === referrer && base.endsWith(CACHED_FILES[0]));

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
				let cached = await cache.match(event.request);
				if (cached != null) {
					if (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
						cached = ensureCrossOriginIsolationHeaders(cached);
					}
					// Mise à jour en arrière-plan pour le prochain chargement.
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

	SW_PATH.write_text(text2, encoding="utf-8")
	print(f"Patched {SW_PATH.name} CACHE_VERSION={version}")


if __name__ == "__main__":
	patch()
