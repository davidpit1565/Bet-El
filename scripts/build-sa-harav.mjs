#!/usr/bin/env node
// Builds data/sa-harav/** (Shulchan Aruch HaRav, the Alter Rebbe) from Sefaria.
//
// Usage: node scripts/build-sa-harav.mjs [--part oc] [--refresh]
//
// SOURCE / LICENSE: Sefaria "Shulchan Arukh HaRav", Hebrew version
//   "Vocalized Edition - Kehot Publication Society" (CC-BY-NC, (c) Kehot Publication Society).
//   Attribution is kept in data/sa-harav/index.json.
//
// WHICH NODE (Orach Chayim): the Sefaria index has three Orach Chayim nodes:
//   - "Second Edition" (Hebrew: מהדורא תניינא): only 4 simanim / 35 paragraphs (fragments of the
//     author's later draft found in his manuscripts) - NOT the standard text.
//   - the unnamed DEFAULT node (ref "Shulchan Arukh HaRav, Orach Chayim <n>"): the complete standard
//     text, 651 simanim slots; Sefaria's siman numbers equal the printed simanim. 140 slots are EMPTY
//     on Sefaria (parts the author did not write / were lost, e.g. 132-154, 216-241, 409-428,
//     530-581) and are skipped here.
//   - "Last Edition" (מהדורא בתרא): only 4 simanim (243, 252, 259, 301), alternative later versions.
//   => We use the DEFAULT node. Output files exist only for non-empty simanim; the empty ones are
//   listed in index.json under part.missing.
// Footnotes (<i data-commentator="Notes">) are dropped; only <b> heading is kept; <br> -> space.
//
// To add another section (e.g. Yoreh Deah) add an entry to PARTS below.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.join(ROOT, 'data', 'sa-harav');
const CACHE = '/tmp/sa-harav-cache';
const VERSION = 'Vocalized Edition - Kehot Publication Society';
const PARTS = {
  oc: { he: 'אורח חיים', ref: 'Shulchan_Arukh_HaRav,_Orach_Chayim' },
  // yd: { he: 'יורה דעה', ref: 'Shulchan_Arukh_HaRav,_Yoreh_Deah' },
};
const args = process.argv.slice(2);
const partKeys = args.includes('--part') ? [args[args.indexOf('--part') + 1]] : Object.keys(PARTS);
const refresh = args.includes('--refresh');

const sleep = ms => new Promise(r => setTimeout(r, ms));
async function getJSON(url, cacheFile) {
  if (!refresh && fs.existsSync(cacheFile)) return JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
  for (let a = 0; a < 6; a++) {
    try {
      const r = await fetch(url);
      if (r.ok) { const t = await r.text(); const j = JSON.parse(t); fs.writeFileSync(cacheFile, t); return j; }
      if (r.status !== 429 && r.status < 500) throw new Error('HTTP ' + r.status + ' ' + url);
    } catch (e) { if (a === 5) throw e; }
    await sleep(1000 * 2 ** a);
  }
}
async function pool(items, n, fn) {
  let i = 0;
  await Promise.all(Array.from({ length: n }, async () => { while (i < items.length) { const k = i++; await fn(items[k], k); } }));
}

const NIKUD = /[֑-ׇ]/g;
const GEM = { א:1,ב:2,ג:3,ד:4,ה:5,ו:6,ז:7,ח:8,ט:9,י:10,כ:20,ך:20,ל:30,מ:40,ם:40,נ:50,ן:50,ס:60,ע:70,פ:80,ף:80,צ:90,ץ:90,ק:100,ר:200,ש:300,ת:400 };
const WORDS = { 'אחד':1,'אחת':1,'שני':2,'שנים':2,'שלשה':3,'שלושה':3,'ארבעה':4,'חמשה':5,'חמישה':5,'ששה':6,'שבעה':7,'שמונה':8,'תשעה':9,'עשרה':10 };
function gem(s) { let n = 0; for (const c of s) { if (GEM[c]) n += GEM[c]; } return n; }
function statedCount(heading) {
  const plain = heading.replace(NIKUD, '').replace(/־/g, ' ');
  if (/(?<![א-ת])ובו\s+סעיף\s+אחד/.test(plain)) return 1;
  const m = plain.match(/(?<![א-ת])ובו\s+(.+?)\s+סעיפים?/);
  if (!m) return null;
  const w = m[1].replace(/["'״׳\[\]]/g, '').trim();
  if (/^סעיף$/.test(w)) return 1;
  if (WORDS[w]) return WORDS[w];
  if (/^[א-ת]{1,4}$/.test(w)) return gem(w);
  return null;
}
function clean(html) {
  let s = html.replace(/<i\b[^>]*><\/i>/g, '').replace(/<br\s*\/?>/gi, ' ');
  s = s.replace(/<(?!\/?b>)[^>]*>/g, '');           // drop every tag except <b>
  s = s.replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>');
  s = s.replace(/<b>\s*<\/b>/g, '').replace(/\s+/g, ' ').replace(/\s*<\/b>\s*/g, '</b> ').trim();
  return s.normalize('NFC');
}
function numeral(n) { // Hebrew numeral for a siman number (fallback title)
  const L = [[400,'ת'],[300,'ש'],[200,'ר'],[100,'ק'],[90,'צ'],[80,'פ'],[70,'ע'],[60,'ס'],[50,'נ'],[40,'מ'],[30,'ל'],[20,'כ'],[10,'י'],[9,'ט'],[8,'ח'],[7,'ז'],[6,'ו'],[5,'ה'],[4,'ד'],[3,'ג'],[2,'ב'],[1,'א']];
  let r = '', x = n;
  for (const [v, c] of L) while (x >= v) { if (x === 15 || x === 16) { r += x === 15 ? 'טו' : 'טז'; x = 0; break; } r += c; x -= v; }
  return r;
}
function headingOf(s) {
  const m = s.match(/<b>(.*?)<\/b>/);
  if (!m) return { full: '', title: '' };
  const full = m[1].replace(/\s+/g, ' ').trim();
  // cut the trailing "וּבוֹ <count> סְעִיפִים" phrase (the LAST standalone "וּבוֹ", at most 3 words after it)
  const w = full.split(' ');
  const k = w.lastIndexOf('וּבוֹ');
  let title = full;
  if (k >= 0 && w.length - k <= 4) title = w.slice(0, k).join(' ');
  title = title.replace(/[,:\s]+$/, '').trim();
  return { full, title };
}

async function buildPart(key) {
  const P = PARTS[key];
  if (!P) throw new Error('unknown part ' + key);
  fs.mkdirSync(CACHE, { recursive: true });
  const shape = (await getJSON(`https://www.sefaria.org/api/shape/${P.ref}`, path.join(CACHE, key + '-shape.json')))[0];
  const N = shape.chapters.length;
  const nums = Array.from({ length: N }, (_, i) => i + 1).filter(n => shape.chapters[n - 1] > 0);
  console.log(`[${key}] shape: ${N} siman slots, ${nums.length} non-empty`);
  const dir = path.join(OUT, key);
  fs.mkdirSync(dir, { recursive: true });
  const simanim = [], problems = [];
  let seifim = 0, chars = 0, words = 0;
  const res = {};
  await pool(nums, 4, async n => {
    const url = `https://www.sefaria.org/api/texts/${P.ref}.${n}?context=0&pad=0&commentary=0&version=${encodeURIComponent('he|' + VERSION)}`;
    const j = await getJSON(url, path.join(CACHE, `${key}-${n}.json`));
    if (j.error) throw new Error(n + ': ' + j.error);
    if (j.heVersionTitle !== VERSION) problems.push(`siman ${n}: version ${j.heVersionTitle}`);
    res[n] = j.he;
  });
  for (const n of nums) {
    const raw = res[n];
    if (!Array.isArray(raw) || !raw.length) { problems.push(`siman ${n}: empty`); continue; }
    const s = raw.map(x => clean(typeof x === 'string' ? x : Array.isArray(x) ? x.join(' ') : ''));
    let { full, title } = headingOf(s[0]);
    if (!full) { // heading-less first seif: use a short first line (e.g. "הלכות פסח") if present
      const r0 = String(raw[0]);
      const first = r0.split(/<br\s*\/?>/i)[0].replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
      if (raw.length > 1 && first && first.length < 40 && /<br/i.test(r0)) title = first.normalize('NFC');
    }
    if (!title || /^[א-ת"'׳״]{1,6}$/.test(title.replace(NIKUD, ''))) {
      problems.push(`siman ${n}: no real heading (full="${full}"), title falls back to the siman numeral`);
      title = 'סִימָן ' + numeral(n);
    }
    const st = statedCount(full);
    if (st !== null && st !== s.length) problems.push(`siman ${n}: heading says ${st} seifim, got ${s.length}`);
    if (st === null && full) problems.push(`siman ${n}: heading count not parsable: ${full}`);
    s.forEach((t, i) => {
      if (!t) problems.push(`siman ${n} seif ${i + 1}: empty`);
      if (/<(?!\/?b>)/.test(t)) problems.push(`siman ${n} seif ${i + 1}: leftover HTML`);
      if (t && !/[ְ-ׇ]/.test(t)) problems.push(`siman ${n} seif ${i + 1}: no nikud`);
      chars += t.length; words += t.split(' ').filter(Boolean).length;
    });
    seifim += s.length;
    fs.writeFileSync(path.join(dir, n + '.json'), JSON.stringify({ n, t: title, s }));
    simanim.push({ n, t: title, s: s.length });
  }
  const missing = Array.from({ length: N }, (_, i) => i + 1).filter(n => !nums.includes(n));
  return { key, he: P.he, simanim, missing, N, seifim, chars, words, problems };
}

const parts = [];
const idxFile = path.join(OUT, 'index.json');
const existing = fs.existsSync(idxFile) ? JSON.parse(fs.readFileSync(idxFile, 'utf8')) : null;
for (const k of partKeys) {
  const r = await buildPart(k);
  console.log(`[${k}] simanim=${r.simanim.length} seifim=${r.seifim} chars=${r.chars} words=${r.words} empty-on-Sefaria=${r.missing.length} (of ${r.N})`);
  console.log(`[${k}] problems: ${r.problems.length}`); r.problems.forEach(p => console.log('  - ' + p));
  parts.push({ key: r.key, he: r.he, missing: r.missing, simanim: r.simanim });
}
const merged = new Map((existing?.parts || []).map(p => [p.key, p]));
parts.forEach(p => merged.set(p.key, p));
fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(idxFile, JSON.stringify({
  v: 1,
  source: 'Sefaria - Shulchan Arukh HaRav, Kehot Publication Society (CC-BY-NC)',
  version: VERSION,
  note: 'Orach Chayim = the default Sefaria node (complete standard text). simanim lists only non-empty simanim; "missing" lists siman numbers that are empty on Sefaria (not written/lost).',
  parts: [...merged.values()],
}));
