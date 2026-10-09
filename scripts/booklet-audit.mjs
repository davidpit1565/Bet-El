// Booklet content audit (read-only): a patched copy of index.html (served
// through page.route, never written to disk) exposes the reader's own
// resolvers, and every segment they resolve for the day - verse, Targum,
// each Rashi / Metzudot comment, Mishnah, Rambam, Zohar, Tanya, all six
// Musar works - must appear word for word in the printed A5 pages (joined
// across page breaks, so a word cut at a break fails too). Also reports each
// section's refs/cycle indices, per-verse commentary counts, stranded
// headings, pages opening on a divider, overflow, duplicate source lines,
// and the back page's shas.org credit + HebrewBooks license. Exits 1 on any
// finding. Needs the local server on :8899 (npm run serve:local).
//
//   node scripts/booklet-audit.mjs [YYYY-MM-DD] [out.json]
import { chromium } from 'playwright';
import { readFileSync, writeFileSync } from 'fs';
const SRC = readFileSync('index.html', 'utf8');
const hook = 'window.go = go;';
if (SRC.split(hook).length !== 2) throw new Error('hook');
const EXPOSE = `window.__bk={bkWeekRows,bkWeekDafs,chokSlotFor,chokSectionsFor,bkSections,bkDate,ckCommFor,ckMusarIndexes,ckMusarSegs,MUSAR_WORKS,ckCycleIndex,ckCycleSegs,ckRambamIndexes,ckRambamTrack,ckTanyaDayEntry,chokMishnahYear,chokSourceLine,CK_COMM,BK_COMM_W,ckDafEntry,bkDafSides,ckMusarUI,get CYC(){return CYC},get MCYC(){return MCYC},get S(){return S}};`;
const PATCHED = SRC.replace(hook, hook + EXPOSE);
const proxy = process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY, bypass: 'localhost,127.0.0.1' } : undefined;
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', proxy });
const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, timezoneId: 'Asia/Jerusalem' });
await ctx.addInitScript(({ iso }) => {
  localStorage.setItem('betel_onboard_v1', '1'); localStorage.setItem('betel_chok_pace_v1', '1');
  const RealDate = Date, offset = new RealDate(iso).getTime() - RealDate.now();
  class FakeDate extends RealDate { constructor(...a) { if (a.length === 0) super(RealDate.now() + offset); else super(...a); } static now() { return RealDate.now() + offset; } }
  FakeDate.UTC = RealDate.UTC; FakeDate.parse = RealDate.parse; window.Date = FakeDate;
}, { iso: (process.argv[2] || '2026-10-27') + 'T10:00:00+02:00' });
for (const host of ['https://cdnjs.cloudflare.com/**', 'https://fonts.googleapis.com/**', 'https://fonts.gstatic.com/**', 'https://api.qrserver.com/**'])
  await ctx.route(host, async r => { try { await r.fulfill({ response: await r.fetch() }); } catch (e) { await r.abort(); } });
await ctx.route('**/shas-daf/**', async r => { const m = /\/shas-daf\/([^/]+)\/(\d+)\/([ab])/.exec(r.request().url());
  try { await r.fulfill({ response: await r.fetch({ url: `https://www.shas.org/daf-pdf/api/?masechta=${m[1]}&daf=${m[2]}&amud=${m[3]}` }) }); } catch (e) { await r.abort(); } });
await ctx.route('http://localhost:8899/index.html', r => r.fulfill({ status: 200, contentType: 'text/html; charset=utf-8', body: PATCHED }));
const p = await ctx.newPage(); p.on('pageerror', e => console.log('PAGEERROR', String(e).slice(0, 300)));
await p.goto('http://localhost:8899/index.html'); await p.waitForTimeout(1200);
await p.evaluate(() => window.go('bookletHome'));
await p.waitForFunction(() => !!document.getElementById('bkOpenBtn'), null, { timeout: 30000 });
await p.evaluate(() => document.getElementById('bkOpenBtn').click());
// the booklet is the whole week: two daf pages per day that has a daf
await p.waitForFunction(() => { const A = window.__bk; return A && document.querySelectorAll('#bkPrint .bk-dafpage').length === 2 * A.bkWeekDafs(A.bkDate()).length && !!document.querySelector('#bkPrint .bk-backpage'); }, null, { timeout: 300000 });
await p.waitForTimeout(1000);
const R = await p.evaluate(() => {
  const A = window.__bk, date0 = A.bkDate(), rows = A.bkWeekRows(date0);
  const tmp = document.createElement('div');
  const txt = h => { tmp.innerHTML = String(h); return tmp.textContent.replace(/\s+/g, ' ').trim(); };
  const pages = [...document.querySelectorAll('#bkPrint .bk-page')];
  const content = pages.filter(pg => !/bk-cover|bk-rights|bk-rav|bk-blank|bk-dedic|bk-tocpage|bk-backpage/.test(pg.className));
  const printed = content.map(pg => pg.querySelector('.bk-pbody').textContent).join(' ').replace(/\s+/g, ' ');
  const miss = [];
  const has = (sec, label, h) => { const t = txt(h); if (t && printed.indexOf(t) < 0) miss.push({ day: out.days.length ? out.days[out.days.length - 1].day : '', sec, label, t: t.slice(0, 80) }); return !!t; };
  const out = { date: date0.toString(), days: [], miss, breaks: [], srcDup: [] };
  rows.forEach(r => {
  const date = r.date, { slot, hd, secs } = A.bkSections(r.date, r.day);
  const day = { day: r.day, date: date.toString(), hd: hd.toString(), slot, secs: [], musar: [] };
  out.days.push(day);
  secs.forEach(s => {
    const o = { key: s.key, kind: s.kind, n: s.items.length, refs: s.refs, src: A.chokSourceLine(s, hd) };
    if (['torah', 'neviim', 'ketuvim', 'haftarah', 'verse'].includes(s.kind) || ['torah', 'neviim', 'ketuvim'].includes(s.key)) {
      const ws = A.BK_COMM_W.filter(w => A.CK_COMM[w].on.indexOf(s.key) >= 0);
      o.verses = s.items.map(v => v.book + ' ' + v.c + ':' + v.v); o.targum = s.items.filter(v => v.targum).length; o.comm = {};
      ws.forEach(w => o.comm[w] = 0);
      o.pv = s.items.map(v => { const c = A.ckCommFor(v.book + ' ' + v.c + ':' + v.v, slot.key) || {}; const r = { id: v.c + ':' + v.v, tg: !!v.targum }; ws.forEach(w => r[w] = (c[w] || []).length); return r; });
      s.items.forEach(v => {
        has(s.key, 'verse ' + v.c + ':' + v.v, v.he); if (v.targum) has(s.key, 'targum ' + v.c + ':' + v.v, v.targum);
        const c = A.ckCommFor(v.book + ' ' + v.c + ':' + v.v, slot.key) || {};
        ws.forEach(w => (c[w] || []).forEach((t, i) => { o.comm[w]++; has(s.key, w + ' ' + v.c + ':' + v.v + '#' + i, t); }));
      });
    } else if (s.kind === 'daf') {
      const e = A.ckDafEntry(s.dIdx); o.daf = { idx: s.dIdx, t: e.t, daf: e.daf, sides: A.bkDafSides(s.dIdx), cycIdx: A.ckCycleIndex(A.CYC.daf, hd) };
    } else {
      s.items.forEach((it, i) => has(s.key, 'item ' + i, typeof it === 'string' ? it : (it.he || it.t)));
    }
    if (s.kind === 'rambam') { o.rIdx = s.rIdx; o.expect = A.ckRambamIndexes(hd); o.track = A.ckRambamTrack(); o.chapters = A.ckRambamIndexes(hd).map(i => A.CYC.rambam.order[i]); }
    if (s.key === 'zohar') { o.zIdx = A.ckCycleIndex(A.CYC.zohar, hd); o.zRef = A.CYC.zohar.order[o.zIdx]; }
    if (s.key === 'tanya') { o.tIdx = s.tIdx; o.tEntry = A.ckTanyaDayEntry(hd); }
    if (s.key === 'mishnah') o.mishnahYear = A.chokMishnahYear(hd);
    day.secs.push(o);
  });
  const mt = A.ckMusarUI();
  if (r.day !== 'night') A.MUSAR_WORKS.forEach(w => {
    const idxs = A.ckMusarIndexes(w.key, hd), segs = [];
    idxs.forEach(i => segs.push(...A.ckMusarSegs(w.key, i)));
    segs.forEach((t, i) => has('musar:' + w.key, 'seg ' + i, t));
    day.musar.push({ key: w.key, name: mt[w.key], idxs, refs: idxs.map(i => A.MCYC[w.key].order[i].ref), nSegs: segs.length });
  });
  });
  out.musarLabels = [...document.querySelectorAll('#bkPrint .bk-ml')].map(e => e.textContent);
  // page-break awkwardness
  content.forEach((pg, pi) => {
    const body = pg.querySelector('.bk-pbody'), kids = [...body.children];
    const last = kids[kids.length - 1], first = kids[0], no = pg.dataset.no;
    if (last && /bk-sec|bk-sub|bk-mn|bk-day/.test(last.className)) out.breaks.push({ page: no, issue: 'heading stranded at page foot: ' + last.textContent.trim().slice(0, 40) });
    if (first && /bk-rule/.test(first.className)) out.breaks.push({ page: no, issue: 'page opens with a divider' });
    const lp = last && last.querySelectorAll ? [...last.querySelectorAll('.bk-p')].pop() : null;
    if (lp) { const ml = lp.querySelector('.bk-ml'); if (ml && lp.textContent.trim() === ml.textContent.trim()) out.breaks.push({ page: no, issue: 'musar label alone at page foot: ' + ml.textContent }); }
    if (body.scrollHeight > body.clientHeight + 1) out.breaks.push({ page: no, issue: 'overflow' });
  });
  // a source line must not repeat within one day (a long Tanya letter can
  // legitimately span several days of the week)
  const srcs = []; let seen = new Set();
  document.querySelectorAll('#bkPrint .bk-day-t, #bkPrint .bk-sec-src').forEach(e => {
    if (e.classList.contains('bk-day-t')) { seen = new Set(); return; }
    const v = e.textContent.trim(); srcs.push(v); if (seen.has(v)) out.srcDup.push(v); seen.add(v);
  });
  out.srcs = srcs;
  out.secTitles = [...document.querySelectorAll('#bkPrint .bk-sec-t')].map(e => e.textContent.trim());
  out.back = { credit: /Scanned Shas provided courtesy of shas\.org/.test(document.querySelector('#bkPrint .bk-backpage').textContent), license: /Limited License/.test(document.querySelector('#bkPrint .bk-backpage').textContent) };
  out.dafPageCredit = [...document.querySelectorAll('#bkPrint .bk-dafpage')].some(pg => /Scanned Shas/.test(pg.textContent));
  out.dafImgs = [...document.querySelectorAll('#bkPrint .bk-dafpage img')].length;
  return out;
});
const OUT = process.argv[3] || 'booklet-audit.json';
writeFileSync(OUT, JSON.stringify(R, null, 1));
const bad = R.miss.length + R.breaks.length + R.srcDup.length + (R.back.credit && R.back.license ? 0 : 1);
console.log('missing segments', R.miss.length, '| page-break issues', R.breaks.length, '| duplicate source lines', R.srcDup.length, '| back-page credit+license', R.back.credit && R.back.license, '->', OUT);
await b.close();
process.exit(bad ? 1 : 0);
