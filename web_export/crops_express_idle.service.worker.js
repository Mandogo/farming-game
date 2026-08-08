// This service worker is required to expose an exported Godot project as a
// Progressive Web App. It provides an offline fallback page telling the user
// that they need an Internet connection to run the project if desired.
// Incrementing CACHE_VERSION will kick off the install event and force
// previously cached resources to be updated from the network.
/** @type {string} */
const CACHE_VERSION = '1786190668|a533779b1b08';
/** @type {string} */
const CACHE_PREFIX = 'Crops Express Id-sw-cache-';
const CACHE_NAME = CACHE_PREFIX + CACHE_VERSION;
/** @type {string} */
const OFFLINE_URL = 'crops_express_idle.offline.html';
/** @type {boolean} */
const ENSURE_CROSSORIGIN_ISOLATION_HEADERS = true;
// Files that will be cached on load.
/** @type {string[]} */
const CACHED_FILES = ["index.html","crops_express_idle.html","crops_express_idle.js","crops_express_idle.offline.html","crops_express_idle.icon.png","crops_express_idle.apple-touch-icon.png","crops_express_idle.audio.worklet.js","crops_express_idle.audio.position.worklet.js"];
// Files that we might not want the user to preload, and will only be cached on first load.
/** @type {string[]} */
const CACHEABLE_FILES = ["crops_express_idle.wasm","crops_express_idle.pck"];
const FULL_CACHE = CACHED_FILES.concat(CACHEABLE_FILES);

self.addEventListener('install', (event) => {
	self.skipWaiting();
	event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));
});

self.addEventListener('activate', (event) => {
	event.waitUntil(caches.keys().then(
		function (keys) {
			// Remove old caches.
			return Promise.all(keys.filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME).map((key) => caches.delete(key)));
		}
	).then(function () {
		// Enable navigation preload if available.
		return ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();
	}).then(function () {
		return self.clients.claim();
	}).then(function () {
		// Force les PWA / onglets déjà ouverts à recharger (HTML neuf).
		return self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (all) {
			return Promise.all(all.map(function (c) {
				try { return c.navigate(c.url); } catch (e) { return undefined; }
			}));
		});
	}));
});

/**
 * Ensures that the response has the correct COEP/COOP headers
 * @param {Response} response
 * @returns {Response}
 */
function ensureCrossOriginIsolationHeaders(response) {
	if (response.headers.get('Cross-Origin-Embedder-Policy') === 'require-corp'
		&& response.headers.get('Cross-Origin-Opener-Policy') === 'same-origin') {
		return response;
	}

	const crossOriginIsolatedHeaders = new Headers(response.headers);
	crossOriginIsolatedHeaders.set('Cross-Origin-Embedder-Policy', 'require-corp');
	crossOriginIsolatedHeaders.set('Cross-Origin-Opener-Policy', 'same-origin');
	const newResponse = new Response(response.body, {
		status: response.status,
		statusText: response.statusText,
		headers: crossOriginIsolatedHeaders,
	});

	return newResponse;
}

/**
 * Calls fetch and cache the result if it is cacheable
 * @param {FetchEvent} event
 * @param {Cache} cache
 * @param {boolean} isCacheable
 * @returns {Response}
 */
async function fetchAndCache(event, cache, isCacheable) {
	// Use the preloaded response, if it's there
	/** @type { Response } */
	let response = await event.preloadResponse;
	if (response == null) {
		// Or, go over network.
		response = await self.fetch(event.request);
	}

	if (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
		response = ensureCrossOriginIsolationHeaders(response);
	}

	if (isCacheable) {
		// And update the cache
		cache.put(event.request, response.clone());
	}

	return response;
}

self.addEventListener(
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
);

self.addEventListener('message', (event) => {
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
		if (msg === 'claim') {
			self.skipWaiting().then(() => self.clients.claim());
		} else if (msg === 'clear') {
			caches.delete(CACHE_NAME);
		} else if (msg === 'update') {
			self.skipWaiting().then(() => self.clients.claim()).then(() => self.clients.matchAll()).then((all) => all.forEach((c) => c.navigate(c.url)));
		}
	});
});

