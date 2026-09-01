const CACHE = 'betel-tehilim-v10';
const SHELL = ['./', './index.html', './manifest.json', './icon-192.png', './icon-512.png'];
const NET_TIMEOUT = 4000;

// fetch() itself never times out in the browser - on a flaky connection a
// request can hang forever instead of failing, which would leave install
// and navigation stuck indefinitely with no fallback ever kicking in.
function withTimeout(promise, ms) {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error('timeout')), ms);
    promise.then(v => { clearTimeout(t); resolve(v); }, e => { clearTimeout(t); reject(e); });
  });
}

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => Promise.allSettled(SHELL.map(url =>
        withTimeout(fetch(url), NET_TIMEOUT).then(res => c.put(url, res)).catch(() => {})
      )))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;

  if (req.mode === 'navigate') {
    e.respondWith(
      withTimeout(fetch(req), NET_TIMEOUT)
        .then(res => {
          const resCopy = res.clone();
          caches.open(CACHE).then(c => c.put(req, resCopy));
          return res;
        })
        .catch(() => caches.match(req).then(r => r || caches.match('./index.html')))
    );
    return;
  }

  e.respondWith(
    caches.match(req).then(cached => {
      const network = withTimeout(fetch(req), NET_TIMEOUT).then(res => {
        if (res.ok) {
          const resCopy = res.clone();
          caches.open(CACHE).then(c => c.put(req, resCopy));
        }
        return res;
      }).catch(() => cached);
      return cached || network;
    })
  );
});
