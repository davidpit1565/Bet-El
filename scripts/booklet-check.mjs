// Study-booklet check: opens the booklet for a faked date, waits for the real
// shas.org daf page to render, and captures the on-screen view, the
// print-media view, Chrome's own print output (page.pdf - the same pipeline
// window.print() uses), one PNG per printed A5 page (cover, dedication, the
// day, back page) and the in-app "PDF" export. Also re-runs the day with
// no daf proxy at all, to prove the plain-citation fallback doesn't throw.
//
// Needs the local server on :8899 (npm run serve:local). The Vercel rewrite
// /shas-daf/<masechta>/<daf>/<amud> (vercel.json) does not exist on that
// plain static server, so it is emulated here with page.route, fetching the
// same shas.org URL the rewrite points at.
//
//   node scripts/booklet-check.mjs [YYYY-MM-DD] [outDir]
import { chromium } from 'playwright';
import { mkdirSync, writeFileSync } from 'fs';

const CHROME_PATH = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const DAY = process.argv[2] || '2026-10-27';          // Tuesday, parashat Vayera
const OUT = process.argv[3] || 'booklet-shots';
mkdirSync(OUT, { recursive: true });

const proxy = process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY, bypass: 'localhost,127.0.0.1' } : undefined;
const b = await chromium.launch({ executablePath: CHROME_PATH, proxy });
const errs = [];

async function openCtx({ withDafProxy }) {
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, timezoneId: 'Asia/Jerusalem', acceptDownloads: true });
  await ctx.addInitScript(({ iso }) => {
    localStorage.setItem('betel_onboard_v1', '1');
    localStorage.setItem('betel_chok_pace_v1', '1');
    const RealDate = Date, offset = new RealDate(iso).getTime() - RealDate.now();
    class FakeDate extends RealDate {
      constructor(...a) { if (a.length === 0) super(RealDate.now() + offset); else super(...a); }
      static now() { return RealDate.now() + offset; }
    }
    FakeDate.UTC = RealDate.UTC; FakeDate.parse = RealDate.parse;
    window.Date = FakeDate;
  }, { iso: DAY + 'T10:00:00+02:00' });
  /* In a sandbox whose egress proxy re-terminates TLS with its own CA, the
     bundled Chromium doesn't trust that CA, so CDN scripts (pdf.js,
     html2canvas, jsPDF) and Google Fonts fail to load at all. Relay those
     hosts through Playwright's Node-side fetch (which does honor
     NODE_EXTRA_CA_CERTS) - the page still receives the exact same bytes.
     Harmless where the browser can reach them directly. */
  for (const host of ['https://cdnjs.cloudflare.com/**', 'https://fonts.googleapis.com/**', 'https://fonts.gstatic.com/**', 'https://api.qrserver.com/**']) {
    await ctx.route(host, async route => {
      try { await route.fulfill({ response: await route.fetch() }); } catch (e) { await route.abort(); }
    });
  }
  if (withDafProxy) {
    await ctx.route('**/shas-daf/**', async route => {
      const m = /\/shas-daf\/([^/]+)\/(\d+)\/([ab])/.exec(route.request().url());
      const url = `https://www.shas.org/daf-pdf/api/?masechta=${m[1]}&daf=${m[2]}&amud=${m[3]}`;
      try { await route.fulfill({ response: await route.fetch({ url }) }); }
      catch (e) { errs.push('PROXY EMULATION: ' + e.message); await route.abort(); }
    });
  }
  const p = await ctx.newPage();
  p.on('pageerror', e => errs.push('PAGEERROR: ' + String(e).slice(0, 500)));
  p.on('console', m => {
    const t = m.text();
    if (/\[booklet\]/.test(t)) console.log('  page:', t.slice(0, 300));
    if (m.type() === 'error' && !/ERR_CONNECTION_RESET|404 \(File not found\)|net::ERR|api\.qrserver/.test(t)) errs.push('CONSOLE: ' + t.slice(0, 400));
  });
  await p.goto('http://localhost:8899/index.html', { waitUntil: 'domcontentloaded', timeout: 30000 });
  await p.waitForTimeout(1200);
  return { ctx, p };
}
const waitFor = (p, fn, ms = 30000) => p.waitForFunction(fn, null, { timeout: ms, polling: 250 });

// ---- 1. full path with the daf proxy ----
{
  const { ctx, p } = await openCtx({ withDafProxy: true });
  await p.evaluate(() => window.go('home'));
  await waitFor(p, () => !!document.getElementById('homeBookletCard'));
  await p.evaluate(() => document.getElementById('homeBookletCard').scrollIntoView({ block: 'center' }));
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${OUT}/0-home.png` });
  await p.evaluate(() => document.getElementById('homeBookletCard').click());
  await waitFor(p, () => !!document.getElementById('bkOpenBtn'));
  await p.screenshot({ path: `${OUT}/1-booklet-home.png`, fullPage: true });
  await p.evaluate(() => document.getElementById('bkOpenBtn').click());
  await waitFor(p, () => !!document.querySelector('.bk-sheet'));
  await waitFor(p, () => !document.querySelector('.bk-sheet .bk-loading') && document.querySelectorAll('#bkPrint .bk-page').length > 0, 90000);
  const info = await p.evaluate(() => ({
    sections: [...document.querySelectorAll('.bk-sheet .bk-sec-t')].map(e => e.textContent),
    sources: [...document.querySelectorAll('.bk-sheet .bk-sec-src')].map(e => e.textContent),
    dafImgs: document.querySelectorAll('.bk-sheet .bk-daf img').length,
    cites: [...document.querySelectorAll('.bk-sheet .bk-cite')].map(e => e.textContent),
    comm: [...document.querySelectorAll('.bk-sheet .bk-comm-l')].map(e => e.textContent),
    pages: document.querySelectorAll('#bkPrint .bk-page').length,
    overflow: [...document.querySelectorAll('#bkPrint .bk-pbody')].filter(b => b.scrollHeight > b.clientHeight + 1).length,
    labels: [...document.querySelectorAll('#bkPrint .bk-ph-lbl')].map(e => e.textContent),
    cover: !!document.querySelector('#bkPrint .bk-page.bk-cover'),
    dedication: !!document.querySelector('#bkPrint .bk-page.bk-dedic'),
    back: !!document.querySelector('#bkPrint .bk-page.bk-backpage'),
    order: [...document.querySelectorAll('#bkPrint .bk-page')].map(pg => ['bk-cover','bk-rights','bk-blank','bk-dedic','bk-tocpage','bk-backpage'].find(c => pg.classList.contains(c)) || 'content'),
    // every two-column flow (Halacha, Musar, Zohar) must really lay out in 2 columns, at body size
    cols: [...document.querySelectorAll('#bkPrint .bk-cols')].map(e => { const cs = getComputedStyle(e), pg = e.closest('.bk-page'); return { lbl: (pg.querySelector('.bk-ph-lbl') || {}).textContent, n: cs.columnCount, fs: cs.fontSize }; }),
    musarBooks: [...document.querySelectorAll('#bkPrint .bk-sec-t')].map(e => e.textContent).filter((v, i, a) => a.indexOf(v) === i),
    qrImgs: document.querySelectorAll('#bkPrint .bk-qr img, #bkPrint .bk-cv-qr img').length,
    dafPages: [...document.querySelectorAll('#bkPrint .bk-dafpage')].map(pg => {
      const im = pg.querySelector('.bk-dafimg'), b = pg.querySelector('.bk-pbody');
      return { img: im ? [im.clientWidth, im.clientHeight] : null, body: [b.clientWidth, b.clientHeight], extra: b.children.length - 1 };
    }),
  }));
  console.log(JSON.stringify(info, null, 1));
  if (!info.dafImgs) errs.push('no daf image rendered with the proxy in place');
  if (info.overflow) errs.push(info.overflow + ' page(s) overflow their body');
  if (!info.cover || !info.dedication || !info.back) errs.push('missing cover/dedication/back page');
  const badCols = info.cols.filter(c => c.n !== '2' || c.fs !== '14px');
  if (!info.cols.length || badCols.length) errs.push('two-column flows wrong: ' + JSON.stringify(badCols.slice(0, 3)));
  if (!info.cols.some(c => /מוּסָר/.test(c.lbl))) errs.push('no two-column Musar flow found');
  // printed-booklet order: cover, rights & contact page, dedication, contents, ... back page, closing blank
  const o = info.order, want = ['bk-cover', 'bk-rights', 'bk-dedic', 'bk-tocpage'];
  if (want.some((c, i) => o[i] !== c) || o[o.length - 2] !== 'bk-backpage' || o[o.length - 1] !== 'bk-blank' || o.slice(4, -2).some(c => c !== 'content'))
    errs.push('page order is ' + o.join(','));
  if (info.qrImgs !== 2) errs.push('expected the QR on the cover and the back page, got ' + info.qrImgs);
  if (info.dafPages.length !== info.dafImgs) errs.push('each scanned amud should get its own page');
  if (info.dafPages.some(d => d.extra)) errs.push('a daf page carries something besides the scan');
  // the app scrolls <body>, not the window, so walk it one screen at a time
  for (let i = 0; i < 32; i++) {
    const more = await p.evaluate(i => {
      const se = document.body; se.scrollTop = i * 640;
      return se.scrollTop + se.clientHeight < se.scrollHeight - 2 || i === 0;
    }, i);
    await p.waitForTimeout(350);
    await p.screenshot({ path: `${OUT}/2-screen-${i}.png` });
    if (!more) break;
  }
  await p.evaluate(() => { document.body.scrollTop = 0; });

  // the in-app PDF export (html2canvas + jsPDF), saved via its download link
  const dl = p.waitForEvent('download', { timeout: 180000 });
  await p.evaluate(() => document.getElementById('bkPdfBtn').click());
  const d = await dl;
  await d.saveAs(`${OUT}/4-export.pdf`);
  console.log('exported PDF:', d.suggestedFilename());

  // print media: what window.print() lays out
  await p.setViewportSize({ width: 600, height: 840 });
  await p.emulateMedia({ media: 'print' });
  await p.waitForTimeout(500);
  await p.screenshot({ path: `${OUT}/3-print-media.png`, fullPage: true });
  const pages = await p.$$('#bkPrint .bk-page');
  for (let i = 0; i < pages.length; i++) await pages[i].screenshot({ path: `${OUT}/5-page-${String(i + 1).padStart(2, '0')}.png` });
  const pdf = await p.pdf({ preferCSSPageSize: true, printBackground: true });
  writeFileSync(`${OUT}/3-print.pdf`, pdf);
  await ctx.close();
}

// ---- 2. no daf proxy (plain static server): citation fallback ----
{
  const { ctx, p } = await openCtx({ withDafProxy: false });
  await p.evaluate(() => window.go('bookletHome'));
  await waitFor(p, () => !!document.getElementById('bkOpenBtn'));
  await p.evaluate(() => document.getElementById('bkOpenBtn').click());
  await waitFor(p, () => !!document.querySelector('.bk-sheet') && !document.querySelector('.bk-sheet .bk-loading'), 60000);
  const fb = await p.evaluate(() => ({ imgs: document.querySelectorAll('.bk-sheet .bk-daf img').length, cites: [...document.querySelectorAll('.bk-sheet .bk-cite')].map(e => e.textContent) }));
  console.log('fallback:', JSON.stringify(fb));
  if (fb.imgs || !fb.cites.length) errs.push('fallback: expected citation lines and no daf image');
  // step through neighbouring days (prev/next) - no throw
  for (const id of ['bkNext', 'bkNext', 'bkPrev', 'bkToday']) {
    await p.evaluate(i => document.getElementById(i)?.click(), id);
    await p.waitForTimeout(1500);
  }
  await ctx.close();
}

console.log('====ERRORS====');
console.log(errs.length ? errs.join('\n') : 'none');
await b.close();
process.exit(errs.length ? 1 : 0);
