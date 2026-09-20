// Church Attendance service worker.
//
// Strategy:
//   * Navigations: network first, fall back to the cached page, then /offline.
//   * Fingerprinted assets (/assets/*): cache first (they never change).
//   * /api, /cable, /users (auth) and anything non-GET: network only. Attendance
//     is never recorded offline; the scanner tells the operator when a scan
//     did not reach the server.
const VERSION = "v1";
const SHELL_CACHE = `shell-${VERSION}`;
const ASSET_CACHE = `assets-${VERSION}`;
const OFFLINE_URL = "/offline";
const NETWORK_ONLY_PREFIXES = ["/api/", "/cable", "/users/", "/service-worker", "/up"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(SHELL_CACHE)
      .then((cache) => cache.addAll([OFFLINE_URL, "/manifest.json", "/icon.svg", "/icon.png", "/icon-192.png"]))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => ![SHELL_CACHE, ASSET_CACHE].includes(key)).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (NETWORK_ONLY_PREFIXES.some((prefix) => url.pathname.startsWith(prefix))) return;

  if (url.pathname.startsWith("/assets/")) {
    event.respondWith(cacheFirst(request, ASSET_CACHE));
    return;
  }

  if (request.mode === "navigate" || (request.headers.get("accept") || "").includes("text/html")) {
    event.respondWith(networkFirst(request));
  }
});

async function cacheFirst(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response.ok) cache.put(request, response.clone());
  return response;
}

async function networkFirst(request) {
  const cache = await caches.open(SHELL_CACHE);
  try {
    const response = await fetch(request);
    // Only cache successful, non-redirected HTML for same-URL fallback; never cache report downloads.
    if (response.ok && !response.redirected && (response.headers.get("content-type") || "").includes("text/html")) {
      cache.put(request, response.clone());
    }
    return response;
  } catch (_) {
    const cached = await cache.match(request);
    if (cached) return cached;
    const offline = await cache.match(OFFLINE_URL);
    return offline || new Response("You are offline.", { status: 503, headers: { "Content-Type": "text/plain" } });
  }
}
