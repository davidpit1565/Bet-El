// Study-booklet check: opens the booklet for a faked date, waits for the
// whole week to build, and captures the on-screen view, the print-media
// view, Chrome's own print output (page.pdf - the same pipeline
// window.print() uses), one PNG per printed A5 page (cover, dedication, the
// days, back page) and the in-app "PDF" export. The Gemara prints as real
// Daf Yomi text (two columns, a title + "דַּף הַיּוֹמִי" sub-line per amud).
// Then steps through neighbouring days to prove nothing throws.
//
// Needs the local server on :8899 (npm run serve:local).
//
//   node scripts/booklet-check.mjs [YYYY-MM-DD] [outDir]
import { chromium } from 'playwright';
import { mkdirSync, writeFileSync } from 'fs';

const CHROME_PATH = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const DAY = process.argv[2] || '2026-10-27';          // Tuesday, parashat Vayera
const OUT = process.argv[3] || 'booklet-shots';
mkdirSync(OUT, { recursive: true });

// Do NOT hand HTTPS_PROXY to the browser itself: Chromium's proxy.bypass does not keep plain
// http://localhost traffic off the proxy in this sandbox (it gets sent as an absolute-URI GET,
// which the egress proxy answers with 405 since it only tunnels CONNECTs), which silently breaks
// every localhost:8899 request including the very first page load. External hosts are already
// routed through Node's own fetch via ctx.route() below, which honors HTTPS_PROXY on its own
// (run with NODE_USE_ENV_PROXY=1 on Node >= 22.21 if it doesn't pick it up automatically).
const b = await chromium.launch({ executablePath: CHROME_PATH });
const errs = [];

async function openCtx() {
  // serviceWorkers:'block' - sw.js intercepts every same-origin GET and re-issues it
  // with the browser's own fetch() from INSIDE the service worker, which never goes
  // through Playwright's ctx.route() the way a page-initiated request does. Blocking SW
  // registration here only affects this check's own isolated context, never real users.
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, timezoneId: 'Asia/Jerusalem', acceptDownloads: true, serviceWorkers: 'block' });
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

// ---- 1. the full path ----
{
  const { ctx, p } = await openCtx();
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
  // the printed booklet is the whole week: wait for its back page
  await waitFor(p, () => !!document.querySelector('#bkPrint .bk-backpage'), 300000);
  await p.waitForTimeout(1500);
  const info = await p.evaluate(() => ({
    sections: [...document.querySelectorAll('.bk-sheet .bk-sec-t')].map(e => e.textContent),
    sources: [...document.querySelectorAll('.bk-sheet .bk-sec-src')].map(e => e.textContent),
    // the Gemara: one two-column text flow per amud, each opened by its own "דַּף
    // הַיּוֹמִי" sub-line; only the day's FIRST amud is preceded by the "גְּמָרָא"
    // cartouche - every later amud transition that day repeats just the sub-line
    // (owner's call, 2026-10-27). Walk day/sec/sub headers in document order to
    // know, for each amud sub-line, whether a cartouche was expected right
    // before it (one just opened, Gemara, and hasn't been consumed yet).
    amudHeads: (() => {
      const seq = [...document.querySelectorAll('#bkPrint .bk-day-t, #bkPrint .bk-sec-t, #bkPrint .bk-sub')];
      let runOpen = false;
      const out = [];
      seq.forEach(e => {
        if (e.classList.contains('bk-day-t')) { runOpen = false; return; }
        if (e.classList.contains('bk-sec-t')) { runOpen = e.textContent.trim() === 'גְּמָרָא'; return; }
        const isDafHead = /^דַּף הַיּוֹמִי/.test(e.textContent.trim());
        if (!isDafHead) { runOpen = false; return; }
        out.push({
          t: e.textContent.trim(),
          title: !!(e.previousElementSibling && e.previousElementSibling.classList.contains('bk-sec')),
          expectCartouche: runOpen,
          flow: !!(e.nextElementSibling && e.nextElementSibling.matches('.bk-text.bk-prose.bk-cols')),
        });
        runOpen = false;
      });
      return out;
    })(),
    days: [...document.querySelectorAll('#bkPrint .bk-day-t')].map(e => e.textContent),
    toc: [...document.querySelectorAll('#bkPrint .bk-toc-day span, #bkPrint .bk-toc-row span')].map(e => e.textContent),
    cites: [...document.querySelectorAll('.bk-sheet .bk-cite')].map(e => e.textContent),
    comm: [...document.querySelectorAll('.bk-sheet .bk-comm-l')].map(e => e.textContent),
    pages: document.querySelectorAll('#bkPrint .bk-page').length,
    overflow: [...document.querySelectorAll('#bkPrint .bk-pbody')].filter(b => b.scrollHeight > b.clientHeight + 1).length,
    labels: [...document.querySelectorAll('#bkPrint .bk-ph-lbl')].map(e => e.textContent),
    cover: !!document.querySelector('#bkPrint .bk-page.bk-cover'),
    dedication: !!document.querySelector('#bkPrint .bk-page.bk-dedic'),
    back: !!document.querySelector('#bkPrint .bk-page.bk-backpage'),
    order: [...document.querySelectorAll('#bkPrint .bk-page')].map(pg => ['bk-cover','bk-rights','bk-rav','bk-blank','bk-dedic','bk-tocpage','bk-backpage'].find(c => pg.classList.contains(c)) || 'content'),
    // every two-column flow (Halacha, Musar, Zohar) must really lay out in 2 columns, at body size
    cols: [...document.querySelectorAll('#bkPrint .bk-cols')].map(e => { const cs = getComputedStyle(e), pg = e.closest('.bk-page'); return { lbl: (pg.querySelector('.bk-ph-lbl') || {}).textContent, n: cs.columnCount, fs: cs.fontSize }; }),
    musarBooks: [...document.querySelectorAll('#bkPrint .bk-sec-t')].map(e => e.textContent).filter((v, i, a) => a.indexOf(v) === i),
    qrImgs: document.querySelectorAll('#bkPrint .bk-qr img, #bkPrint .bk-cv-qr img').length,
  }));
  console.log(JSON.stringify(info, null, 1));
  if (!info.amudHeads.length) errs.push('no Gemara amud header found');
  const badAmud = info.amudHeads.filter(h => !h.flow || h.title !== h.expectCartouche);
  if (badAmud.length) errs.push('Gemara amud header missing its text flow, or cartouche repeated/missing: ' + JSON.stringify(badAmud.slice(0, 3)));
  if (!info.cols.some(c => /גְּמָרָא/.test(c.lbl))) errs.push('no two-column Gemara flow found');
  if (info.overflow) errs.push(info.overflow + ' page(s) overflow their body');
  if (!info.cover || !info.dedication || !info.back) errs.push('missing cover/dedication/back page');
  const badCols = info.cols.filter(c => c.n !== '2' || c.fs !== '17.5px');
  if (!info.cols.length || badCols.length) errs.push('two-column flows wrong: ' + JSON.stringify(badCols.slice(0, 3)));
  if (!info.cols.some(c => /מוּסָר/.test(c.lbl))) errs.push('no two-column Musar flow found');
  // printed-booklet order: cover, rights & contact page, dedication, contents, ... back page, closing blank
  // a blank page (the inside of the cover) sits between the cover and the rights page
  const o = info.order, want = ['bk-cover', 'bk-blank', 'bk-rights', 'bk-rav', 'bk-dedic', 'bk-tocpage'];
  if (want.some((c, i) => o[i] !== c) || o[o.length - 2] !== 'bk-backpage' || o[o.length - 1] !== 'bk-blank' || o.slice(6, -2).some(c => c !== 'content'))
    errs.push('page order is ' + o.join(','));
  if (info.qrImgs !== 2) errs.push('expected the QR on the cover and the back page, got ' + info.qrImgs);
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
  const dl = p.waitForEvent('download', { timeout: 600000 });   // ~4s a page at scale 3
  await p.evaluate(() => { window.__bkPdfT = performance.now(); document.getElementById('bkPdfBtn').click(); });
  const d = await dl;
  await d.saveAs(`${OUT}/4-export.pdf`);
  console.log('exported PDF:', d.suggestedFilename());

  // print media: what window.print() lays out
  await p.setViewportSize({ width: 600, height: 840 });
  await p.emulateMedia({ media: 'print' });
  await p.waitForTimeout(500);
  // a whole week is ~170 pages: one full-page capture is too tall, so the viewport only
  await p.screenshot({ path: `${OUT}/3-print-media.png` });
  const pages = await p.$$('#bkPrint .bk-page');
  for (let i = 0; i < pages.length; i++) await pages[i].screenshot({ path: `${OUT}/5-page-${String(i + 1).padStart(3, '0')}.png`, timeout: 120000 });
  const pdf = await p.pdf({ preferCSSPageSize: true, printBackground: true });
  writeFileSync(`${OUT}/3-print.pdf`, pdf);
  await ctx.close();
}

// ---- 2. neighbouring days ----
{
  const { ctx, p } = await openCtx();
  await p.evaluate(() => window.go('bookletHome'));
  await waitFor(p, () => !!document.getElementById('bkOpenBtn'));
  await p.evaluate(() => document.getElementById('bkOpenBtn').click());
  await waitFor(p, () => !!document.querySelector('.bk-sheet'), 60000);
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
