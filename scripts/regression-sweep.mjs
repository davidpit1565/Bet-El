// Full-app navigation regression sweep. Exercises every main tab plus the
// Chok LeYisrael, Zohar and Shnayim Mikra readers, and reports any thrown
// error or unexpected console error along the way.
//
// Requires a local static server on http://localhost:8899 serving the repo
// root, e.g. (from the repo root):
//   python3 -c "from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler; ThreadingHTTPServer(('127.0.0.1', 8899), SimpleHTTPRequestHandler).serve_forever()" &
// (the plain single-threaded http.server module can stall under concurrent
// requests - use ThreadingHTTPServer as above, not `python3 -m http.server`).
//
// Uses `window.go(...)`, one of the few functions the app's single wrapping
// IIFE exposes on window (see index.html's `window.x = x;` block near the
// end of the main script) - everything else in the app is only reachable by
// clicking real DOM elements, not by calling internal functions from
// page.evaluate(). Playwright's `chromium` is expected as a global package
// (see `npm root -g` / `/opt/pw-browsers/`) - not a project devDependency.
import { chromium } from 'playwright';

const CHROME_PATH = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';

const b = await chromium.launch({ executablePath: CHROME_PATH });
const errs = [];
const ctx = await b.newContext({ viewport: { width: 390, height: 844 } });
await ctx.addInitScript(() => {
  localStorage.setItem('betel_onboard_v1', '1');
  localStorage.setItem('betel_chok_pace_v1', '1');
});
const p = await ctx.newPage();
p.on('pageerror', e => errs.push('PAGEERROR: ' + String(e).slice(0, 500)));
p.on('console', m => {
  const t = m.text();
  if (m.type() === 'error' && !/ERR_CONNECTION_RESET|404 \(File not found\)|net::ERR|api\.qrserver/.test(t)) {
    errs.push('CONSOLE: ' + t.slice(0, 400));
  }
});

await p.goto('http://localhost:8899/index.html', { waitUntil: 'domcontentloaded', timeout: 20000 });
await p.waitForTimeout(1000);

const steps = [
  ['home', () => window.go('home')],
  ['tehillim grid', () => window.go('tehillim')],
  ['tehillim chapter', () => document.querySelector('.ps-cell')?.click()],
  ['prayers', () => window.go('prayers')],
  ['calendar', () => window.go('calendar')],
  ['calendar next month', () => document.getElementById('calNextM')?.click()],
  ['calendar day detail', () => document.querySelector('.cal-cell:not(.empty)')?.click()],
  ['settings', () => window.go('settings')],
  ['theme toggle on', () => document.getElementById('tgTheme')?.click()],
  ['theme toggle off', () => document.getElementById('tgTheme')?.click()],
  ['home again', () => window.go('home')],
  ['chok leyisrael open', () => document.getElementById('homeChokCard')?.click()],
  ['chok section next', () => document.getElementById('ckSecNext')?.click()],
  ['chok day next', () => document.getElementById('ckDayNext')?.click()],
  ['zohar list', () => window.go('zoharList')],
  ['zohar open day', () => document.querySelector('.prayer-row')?.click()],
  ['zohar next', () => document.getElementById('zhNext')?.click()],
  ['zohar toggle done', () => document.getElementById('zhToggleDone')?.click()],
  ['zohar toggle undone', () => document.getElementById('zhToggleDone')?.click()],
  ['home for shnayim', () => window.go('home')],
  ['shnayim mikra', () => document.getElementById('homeParshaCard')?.click()],
  ['home for tehillim daily', () => window.go('home')],
  ['tehillim daily reading', () => document.getElementById('homeTehillimCard')?.click()],
  ['home for ben ish chai', () => window.go('home')],
  ['ben ish chai open', () => document.getElementById('homeBicCard')?.click()],
  ['home for musar', () => window.go('home')],
  ['musar list open', () => document.getElementById('homeMusarCard')?.click()],
  ['musar work open', () => document.querySelector('[data-musarday]')?.click()],
];

for (const [label, fn] of steps) {
  await p.evaluate(fn);
  await p.waitForTimeout(300);
  console.log('ok:', label);
}

console.log('bottom-nav count:', await p.evaluate(() => document.querySelectorAll('.bottom-nav').length));
console.log('nav-pill count:', await p.evaluate(() => document.querySelectorAll('.nav-pill').length));
console.log('sw registered:', await p.evaluate(async () => (await navigator.serviceWorker.getRegistrations()).length));

// A brand-new user (only betel_onboard_v1 set, no betel_chok_pace_v1) hits
// the first-open pace wizard instead of going straight to chokList - its own
// context, since the main steps above pre-skip that wizard entirely. This
// caught a real bug once (when the Halacha step still offered Ben Ish Chai
// as one of its options): an unguarded ensureBicIndex().then(rerender) on
// that step re-triggered itself every render, hanging the page in an
// infinite microtask loop the moment a fresh user reached that screen. Kept
// as a general fresh-user-wizard smoke test now that Ben Ish Chai is its
// own standalone reader, not a Halacha-step option.
const ctx2 = await b.newContext({ viewport: { width: 390, height: 844 } });
await ctx2.addInitScript(() => localStorage.setItem('betel_onboard_v1', '1'));
const p2 = await ctx2.newPage();
p2.on('pageerror', e => errs.push('WIZARD PAGEERROR: ' + String(e).slice(0, 500)));
await p2.goto('http://localhost:8899/index.html', { waitUntil: 'domcontentloaded', timeout: 20000 });
await p2.waitForTimeout(800);
await p2.evaluate(() => window.go('chokList'));
await p2.waitForTimeout(500);
await p2.click('[data-pace-opt="he"]', { timeout: 5000 }).catch(e => errs.push('WIZARD lang step: ' + e.message));
await p2.waitForTimeout(500);
await p2.click('#paceIntroGo', { timeout: 5000 }).catch(e => errs.push('WIZARD intro step: ' + e.message));
await p2.waitForTimeout(800);
try {
  const timeout = new Promise((_, rej) => setTimeout(() => rej(new Error('evaluate timed out (5s) - page likely hung')), 5000));
  const halachaOpts = await Promise.race([
    p2.evaluate(() => [...document.querySelectorAll('[data-pace-opt]')].length),
    timeout,
  ]);
  console.log('ok: fresh-user pace wizard halacha step (' + halachaOpts + ' options)');
  if (halachaOpts < 2) errs.push('WIZARD: expected 2 halacha options, got ' + halachaOpts);
} catch (e) {
  errs.push('WIZARD halacha step hung or errored: ' + e.message);
}
await ctx2.close();

console.log('====ERRORS====');
console.log(errs.length ? errs.join('\n') : 'none');
await b.close();
process.exit(errs.length ? 1 : 0);
