#!/usr/bin/env node
// Regression guard for the Daily Rambam (data/chok-cycles.json "rambam" + data/chok-rambam/*).
//
// Original bug: rambam.order had been sorted ALPHABETICALLY by Sefaria's English titles ("Admission into the Sanctuary"
// first ... "Woman Suspected of Infidelity" last) instead of Mishneh Torah order, so the app's daily Rambam did not
// match the official Daily Rambam. (Rebuild correctly with scripts/build-rambam-cycle.mjs - never sort titles.)
//
// (a) Static, always runs: order is canonical (first = Foundations of the Torah, last = Kings and Wars, 84 books,
//     1006 chapters, no duplicates, chapters 1..N per book, sefarim contiguous in the canonical 14-sefer sequence of
//     index.html's RAMBAM_SEFER_ORDER), and every block file holds exactly its slice of the order.
// (b) Network, skipped with a message when offline: compares the formula below (= what index.html must implement,
//     see ckRambamIndexes) with Sefaria's calendars API for >= 30 dates on both tracks incl. cycle edges.
//     Dates after 2028-11-15 are not compared for the 3-chapter track (Sefaria publishes no 3-chapter data there).
// Usage: node scripts/check-rambam-cycle.mjs [--offline] [--cycles FILE] [--blocks DIR]
import { readFileSync, existsSync } from 'fs';
const root = new URL('..', import.meta.url).pathname;
const args = process.argv.slice(2);
const cf = args.includes('--cycles') ? args[args.indexOf('--cycles') + 1] : root + 'data/chok-cycles.json';
const bd = args.includes('--blocks') ? args[args.indexOf('--blocks') + 1] : root + 'data/chok-rambam';
const cyc = JSON.parse(readFileSync(cf, 'utf8'));
const R = cyc.rambam, order = R.order, n = order.length;
const bad = [];

// ---- (a) static ----
if (n !== 1006) bad.push(`order has ${n} chapters, expected 1006`);
if (order[0]?.book !== 'Mishneh Torah, Foundations of the Torah') bad.push('first book is not Foundations of the Torah: ' + order[0]?.book);
if (order[n - 1]?.book !== 'Mishneh Torah, Kings and Wars') bad.push('last book is not Kings and Wars: ' + order[n - 1]?.book);
if (new Set(order.map(e => e.ref)).size !== n) bad.push('duplicate refs in order');
const bookList = [], seenBooks = new Set();
let prevBook = null, prevCh = 0;
for (const e of order) {
  if (e.book !== prevBook) { if (seenBooks.has(e.book)) bad.push('book not contiguous: ' + e.book); seenBooks.add(e.book); bookList.push(e.book); prevBook = e.book; prevCh = 0; }
  if (e.ch !== prevCh + 1 || e.ref !== `${e.book} ${e.ch}`) bad.push('chapter sequence broken at ' + e.ref);
  prevCh = e.ch;
}
if (bookList.length !== 84) bad.push(`${bookList.length} books, expected 84`);
const html = readFileSync(root + 'index.html', 'utf8');
const m = html.match(/const RAMBAM_SEFER_ORDER=\[(.*?)\];/s);
const seferSeq = m ? [...m[1].matchAll(/'([^']+)'/g)].map(x => x[1]) : null;
if (!seferSeq || seferSeq.length !== 14) bad.push('cannot read RAMBAM_SEFER_ORDER (14) from index.html');
else {
  const seq = []; for (const b of bookList) { const s = R.sefarim[b]; if (!s) bad.push('no sefarim entry for ' + b); else if (seq[seq.length - 1] !== s) seq.push(s); }
  if (seq.length !== 14 || seq.some((s, i) => s !== seferSeq[i])) bad.push('sefarim sequence is not the canonical 14-sefer order: ' + seq.length + ' groups');
}
for (const b of bookList) if (!R.heNames[b]) bad.push('no heNames entry for ' + b);
// block files must match the order slice exactly (the app finds text by block index)
const BLK = cyc.block;
for (const v of ['', '.en', '.fr', '.ru', '.ka']) for (let b = 0; b * BLK < n; b++) {
  const p = `${bd}/${b}${v}.json`; if (!existsSync(p)) { bad.push('missing ' + p); continue; }
  const keys = Object.keys(JSON.parse(readFileSync(p, 'utf8'))), want = order.slice(b * BLK, (b + 1) * BLK).map(e => e.ref);
  if (keys.length !== want.length || keys.some((k, i) => k !== want[i])) bad.push(`block ${b}${v}.json does not match order[${b * BLK}..]`);
}

// ---- the formula (index.html must compute exactly this; `cycle` comes from the data file) ----
const C = R.cycle;
if (!C) bad.push('rambam.cycle (official cycle parameters) missing');
const DAY = 86400000, utc = s => Date.parse(s + 'T00:00:00Z');
const mod = (a, b) => ((a % b) + b) % b;
function readings(dateStr) {     // -> {1:[idx...]|[] (intro day), 3:[...]}
  const e = Math.round((utc(dateStr) - utc(C.start)) / DAY), skip = [...C.skip1].sort((a, b) => a - b);
  const n3 = Math.floor(n / 3), extra = n - 3 * n3;
  const p1 = mod(e, C.intro1 + n - skip.length), p3 = mod(e, C.intro3 + n3);
  let r1 = []; if (p1 >= C.intro1) { let i = p1 - C.intro1; for (const s of skip) if (i >= s) i++; r1 = [i]; }
  let r3 = []; if (p3 >= C.intro3) { const k = p3 - C.intro3, first = 3 * k + (k > C.long3 ? extra : 0), size = 3 + (k === C.long3 ? extra : 0); r3 = Array.from({ length: size }, (_, j) => first + j); }
  return { 1: r1, 3: r3 };
}
const idxOf = new Map(order.map((e, i) => [e.ref, i]));
function parseRef(r) {            // "Mishneh Torah, X 10-12" -> indexes, or null (intro/other)
  const mm = r.match(/^(.*) (\d+)(?:-(\d+))?$/); if (!mm) return null;
  const out = []; for (let c = +mm[2]; c <= +(mm[3] || mm[2]); c++) { const i = idxOf.get(`${mm[1]} ${c}`); if (i === undefined) return null; out.push(i); }
  return out;
}
async function official(d) {
  const [y, mo, da] = d.split('-').map(Number);
  const r = await fetch(`https://www.sefaria.org/api/calendars?diaspora=0&custom=sephardic&year=${y}&month=${mo}&day=${da}`, { signal: AbortSignal.timeout(20000) });
  if (!r.ok) throw new Error('HTTP ' + r.status);
  const items = (await r.json()).calendar_items, out = { 1: [], 3: [] };
  for (const it of items) { const t = it.title.en; const k = t === 'Daily Rambam' ? 1 : t === 'Daily Rambam (3 Chapters)' ? 3 : 0; if (!k) continue; const p = parseRef(it.ref); if (p) out[k].push(...p); }
  return out;
}
const same = (a, b) => a.length === b.length && a.every((x, i) => x === b[i]);

// ---- (b) network ----
let compared = 0, skipped = null;
if (C && !args.includes('--offline')) {
  const dates = new Set(['2026-02-03', '2026-02-06', '2026-02-07', '2026-02-14', '2026-02-15', '2026-03-30', '2026-03-31', '2026-05-21', '2026-05-22', '2026-11-05',
    '2027-01-07', '2027-01-08', '2027-01-11', '2027-01-12', '2027-12-12', '2027-12-13', '2027-12-16', '2027-12-17', '2028-11-14', '2028-11-15', '2028-11-27', '2028-11-28', '2028-11-29']);
  const t0 = utc('2026-02-03'); for (let k = 0; k < 14; k++) dates.add(new Date(t0 + (k * 73 + 20) * DAY).toISOString().slice(0, 10));
  try {
    for (const d of [...dates].sort()) {
      const o = await official(d), a = readings(d);
      for (const k of [1, 3]) {
        if (k === 3 && d > '2028-11-15') continue;
        compared++;
        if (!same(o[k], a[k])) bad.push(`${d} track ${k}: official ${o[k].map(i => order[i]?.ref)} vs app ${a[k].map(i => order[i]?.ref)}`);
      }
    }
  } catch (e) { skipped = 'Sefaria not reachable (' + e.message + ')'; }
} else skipped = args.includes('--offline') ? '--offline' : null;
console.log(`static checks done; ${compared ? 'compared ' + compared + ' official readings with Sefaria' : 'network comparison SKIPPED' + (skipped ? ': ' + skipped : '')}`);
if (bad.length) { console.error('RAMBAM CYCLE CHECK FAILED:\n - ' + bad.slice(0, 30).join('\n - ')); process.exit(1); }
console.log('rambam cycle OK');
