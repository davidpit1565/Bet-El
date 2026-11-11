// Shared helpers for scripts/build-chok-comm.mjs and scripts/check-chok-comm.mjs.
//
// The Chok LeYisrael bundles (data/chok-leyisrael/<Parasha>.json) hold, per daily verse list, a `_comm` map
// "Book c:v" -> {rashi|targum|mdavid|mzion|ohc: [paragraph, ...]}. This module knows which verses every
// bundle's lists cover (with REAL chapter lengths), which commentary sources apply to which book, where each
// source lives on Sefaria, and how to fetch + cache it (4 parallel max, retry/backoff, raw responses in /tmp).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const CACHE = process.env.CHOK_COMM_CACHE || '/tmp/chok-comm-cache';
export const LANGS = ['en', 'fr', 'ru', 'ka'];
const readJSON = (p) => JSON.parse(fs.readFileSync(path.join(ROOT, p), 'utf8'));

export const INDEX = readJSON('data/chok-leyisrael-index.json');
const NEVIIM = readJSON('data/neviim-data.json');
const KETUVIM = readJSON('data/ketuvim-data.json');
const TORAH = readJSON('data/torah-data.json');

// Tehillim lives only inline in index.html (`window.TEHILLIM={"1":[verses],...}`)
function tehillimLengths() {
  const html = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
  const i = html.indexOf('window.TEHILLIM={') + 'window.TEHILLIM='.length;
  let depth = 0, inStr = false, j = i;
  for (; j < html.length; j++) {            // find the matching closing brace of the object literal
    const ch = html[j];
    if (inStr) { if (ch === '\\') j++; else if (ch === '"') inStr = false; continue; }
    if (ch === '"') inStr = true; else if (ch === '{') depth++; else if (ch === '}' && --depth === 0) { j++; break; }
  }
  const o = JSON.parse(html.slice(i, j));
  const out = [];
  for (const k of Object.keys(o)) out[+k - 1] = o[k].length;
  return out;
}

export const CH_LEN = {};
for (const [b, ch] of Object.entries(NEVIIM)) CH_LEN[b] = ch.map((c) => c.length);
for (const [b, ch] of Object.entries(KETUVIM)) CH_LEN[b] = ch.map((c) => c.length);
for (const [b, ch] of Object.entries(TORAH)) CH_LEN[b] = ch.map((c) => c.length);
CH_LEN.Psalms = tehillimLengths();
export const TORAH_BOOKS = new Set(Object.keys(TORAH));
export { TORAH };

export const slug = (s) => s.replace(/[^A-Za-z0-9]+/g, '-').replace(/^-|-$/g, '');

// "Book c:v", "Book c:v1-v2", "Book c1:v1-c2:v2"
const REF = /^(.*?) (\d+):(\d+)(?:-(?:(\d+):)?(\d+))?$/;
export function parseRef(r) {
  const m = REF.exec(r);
  if (!m) return null;
  const c1 = +m[2], v1 = +m[3];
  const c2 = m[4] ? +m[4] : c1;
  const v2 = m[5] ? +m[5] : v1;
  return { book: m[1], c1, v1, c2, v2 };
}
// every (chapter, verse) of a ref, using the real chapter lengths
export function expandRef(p) {
  const out = [];
  for (let c = p.c1; c <= p.c2; c++) {
    const len = (CH_LEN[p.book] || [])[c - 1];
    if (!len) throw new Error(`no chapter length for ${p.book} ${c}`);
    const a = c === p.c1 ? p.v1 : 1, z = c === p.c2 ? p.v2 : len;
    for (let v = a; v <= z; v++) out.push([c, v]);
  }
  return out;
}

// which sources a book carries, and where they live on Sefaria
export const sourcesFor = (book) => (TORAH_BOOKS.has(book) ? ['rashi', 'ohc'] : ['rashi', 'targum', 'mdavid', 'mzion']);
export function sefariaTitle(w, book) {
  switch (w) {
    case 'rashi': return `Rashi on ${book}`;
    case 'ohc': return `Or HaChaim on ${book}`;
    case 'mdavid': return `Metzudat David on ${book}`;
    case 'mzion': return `Metzudat Zion on ${book}`;
    case 'targum': return (NEVIIM[book] ? 'Targum Jonathan on ' : 'Aramaic Targum to ') + book;
  }
  throw new Error('source ' + w);
}

export const parashaList = () => INDEX.parshiot.map((p) => ({ name: p, file: slug(p) }));
export const bundlePath = (file, lang) => `data/chok-leyisrael/${file}${lang && lang !== 'he' ? '.' + lang : ''}.json`;
export const loadBundle = (file, lang) => JSON.parse(fs.readFileSync(path.join(ROOT, bundlePath(file, lang)), 'utf8'));

// Which verses a parasha's bundle must be able to show commentary for: every ref of its schedule in the
// torah / tzeruf / neviim / ketuvim / haftarah sections. -> Map "Book c:v" -> Set(section)
export function universe(parashaName) {
  const m = new Map();
  const days = INDEX.schedule[parashaName] || {};
  for (const d of Object.values(days)) {
    for (const [sec, refs] of Object.entries(d)) {
      // (haftarah-only verses are not part of the bundles' commentary design: no haftarah-only verse has _comm at all)
      if (!['torah', 'tzeruf', 'neviim', 'ketuvim'].includes(sec)) continue;
      for (const r of refs) {
        const p = parseRef(r);
        if (!p || !CH_LEN[p.book]) continue;
        for (const [c, v] of expandRef(p)) {
          const id = `${p.book} ${c}:${v}`;
          if (!m.has(id)) m.set(id, new Set());
          m.get(id).add(sec);
        }
      }
    }
  }
  return m;
}

// ---- Sefaria (v3 texts, primary Hebrew version), cached raw on disk ----
fs.mkdirSync(CACHE, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let active = 0; const waiters = [];
async function slot() { if (active >= 4) await new Promise((r) => waiters.push(r)); active++; }
function release() { active--; const w = waiters.shift(); if (w) w(); }

async function sefariaRaw(title, chapter) {
  const key = (title + ' ' + chapter).replace(/[^A-Za-z0-9]+/g, '_');
  const f = path.join(CACHE, key + '.json');
  if (fs.existsSync(f)) return JSON.parse(fs.readFileSync(f, 'utf8'));
  const url = 'https://www.sefaria.org/api/v3/texts/' + encodeURIComponent(`${title} ${chapter}`) + '?version=hebrew';
  await slot();
  try {
    for (let k = 0; k < 6; k++) {
      try {
        const res = await fetch(url, { signal: AbortSignal.timeout(60000) });
        if (res.status === 404 || res.status === 400) { const j = { _none: res.status }; fs.writeFileSync(f, JSON.stringify(j)); return j; }
        if (!res.ok) throw new Error('HTTP ' + res.status);
        const j = await res.json();
        // Sefaria answers 200 + {error} for "no such chapter in this commentary"
        const slim = j.error ? { _none: j.error } : { versions: (j.versions || []).map((v) => ({ versionTitle: v.versionTitle, text: v.text })) };
        fs.writeFileSync(f, JSON.stringify(slim));
        return slim;
      } catch (e) {
        if (k === 5) throw new Error(`${url}: ${e.message}`);
        await sleep(1500 * 2 ** k);
      }
    }
  } finally { release(); }
}

// -> { version, verses: Map(verseNo -> [paragraph strings]) } for one chapter of one commentary
export async function sefariaChapter(w, book, chapter) {
  const raw = await sefariaRaw(sefariaTitle(w, book), chapter);
  const verses = new Map();
  const v0 = raw.versions && raw.versions[0];
  if (!v0) return { version: null, verses };
  let t = v0.text;
  if (typeof t === 'string') t = [t];
  (t || []).forEach((x, i) => {
    const arr = (Array.isArray(x) ? x.flat(3) : [x]).filter((s) => typeof s === 'string' && s.trim());
    if (arr.length) verses.set(i + 1, arr.map(cleanPara));
  });
  return { version: v0.versionTitle, verses };
}
// One verse. A chapter request only returns the PRIMARY Hebrew version; a verse the primary version lacks (Rashi on
// Exodus 8:28 / 20:6, Deuteronomy 31:1, ...) is answered from the next version that has it.
export async function sefariaVerse(w, book, c, v) {
  const raw = await sefariaRaw(sefariaTitle(w, book), `${c}:${v}`);
  const v0 = raw.versions && raw.versions[0];
  if (!v0) return null;
  let t = v0.text;
  if (typeof t === 'string') t = [t];
  const arr = (t || []).flat(3).filter((s) => typeof s === 'string' && s.trim());
  return arr.length ? { version: v0.versionTitle, paras: arr.map(cleanPara) } : null;
}
// same cleanup the bundles already went through ("Data: strip stray \u0001 footnote-marker artifacts")
export const cleanPara = (s) => s.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, '');

// ---- writing a bundle back in the SAME byte format it was read in ----
// Hebrew bundles are compact JSON; the translated variants use python's json.dumps(ensure_ascii=False) separators.
export function pyDumps(v) {
  if (Array.isArray(v)) return '[' + v.map(pyDumps).join(', ') + ']';
  if (v && typeof v === 'object') return '{' + Object.entries(v).map(([k, x]) => JSON.stringify(k) + ': ' + pyDumps(x)).join(', ') + '}';
  return JSON.stringify(v);
}
export function readBundleRaw(file, lang) {
  const text = fs.readFileSync(path.join(ROOT, bundlePath(file, lang)), 'utf8');
  const obj = JSON.parse(text);
  const style = JSON.stringify(obj) === text ? 'compact' : pyDumps(obj) === text ? 'py' : null;
  if (!style) throw new Error('unknown JSON layout: ' + bundlePath(file, lang));
  return { obj, style };
}
export function writeBundle(file, lang, obj, style) {
  fs.writeFileSync(path.join(ROOT, bundlePath(file, lang)), style === 'py' ? pyDumps(obj) : JSON.stringify(obj));
}
export const SRC_ORDER = ['rashi', 'targum', 'mdavid', 'mzion', 'ohc'];

// ---- DH vocalization for Torah Rashi (copy the verse's own pointing onto the bare dibbur hamatchil) ----
const strip = (w) => w.replace(/[֑-ׇ]/g, '');
// Rashi's dibbur hamatchil is printed bare while the verse it quotes is pointed: copy the verse's pointing onto it,
// matched on consonants in reading order (maqaf-joined words are indexed both whole and split). Words that are not
// in the verse stay bare; הוא stays bare (הוּא / הִוא cannot be told from the consonants) and לא / ולא lose their
// cantillation - exactly what the existing Torah bundles do (see the match rate printed by build-chok-comm.mjs --selftest).
export function vocalizeDH(para, verseTexts) {
  const m = /^<b>(.*?)<\/b>/s.exec(para);
  if (!m) return para;
  const cands = []; // {k: consonants, val: pointed word, pos}
  let t = 0;
  for (const vt of verseTexts) {
    for (const tok of vt.replace(/<[^>]*>/g, '').split(/\s+/)) {
      if (!tok) continue;
      const clean = (w) => w.replace(/[׀׃]/g, '');
      const parts = tok.split('־');
      const whole = clean(tok.replace(/־/g, ''));
      if (strip(whole)) cands.push({ k: strip(whole), val: whole, pos: t + 0.05 });
      parts.forEach((p, i) => { const c = clean(p); if (strip(c)) cands.push({ k: strip(c), val: c, pos: t + 0.1 * (i + 1) }); });
      t++;
    }
  }
  const dh = m[1].replace(/\S+/g, (w) => {
    if (/[ְ-ׇ]/.test(w)) return w;
    const core = w.replace(/[.,:;'"״׳־]+$/g, '');
    const tail = w.slice(core.length);
    const hit = cands.find((c) => c.k === core);   // first occurrence in the verse (reading-order matching scored lower against the existing bundles)
    if (!hit) return w;
    if (core === 'הוא') return w;
    let val = hit.val;
    if (/^ו?לא$/.test(core)) val = val.replace(/[֑-ֽ֯]/g, '');
    return val + tail;
  });
  return '<b>' + dh + '</b>' + para.slice(m[0].length);
}
