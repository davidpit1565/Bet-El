#!/usr/bin/env node
// Fill the commentary the Chok LeYisrael bundles never got (see CLAUDE.md "data/" rules).
//
//   node scripts/build-chok-comm.mjs            # dry run: prints what would be added
//   node scripts/build-chok-comm.mjs --write    # edits data/chok-leyisrael/*.json (+ the en/fr/ru/ka variants)
//   node scripts/build-chok-comm.mjs --mine-lexicon   # (re)build scripts/chok-comm-lexicon.json from the existing variants
//   node scripts/build-chok-comm.mjs --selftest # how well vocalizeDH / the transliteration reproduce the existing entries
//
// For every parasha bundle it expands each torah / tzeruf / neviim / ketuvim ref of the schedule into verses USING
// REAL CHAPTER LENGTHS (the old data prep stopped a chapter early for refs that cross a chapter boundary), and for
// every verse that has no entry - or lacks a source Sefaria has - fetches that source from Sefaria (primary Hebrew
// version, cached raw under /tmp/chok-comm-cache; 4 requests in parallel, retry with backoff). It only ever ADDS:
// existing text is never touched, a source Sefaria has nothing for stays absent. New Rashi / Targum / Or HaChaim
// paragraphs are also transliterated into the four variants (Metzudot stay Hebrew-only, as today).
import fs from 'node:fs';
import * as L from './chok-comm-lib.mjs';

const WRITE = process.argv.includes('--write');
const only = (process.argv.find((a) => a.startsWith('--only=')) || '').slice(7);

if (process.argv.includes('--mine-lexicon') || process.argv.includes('--selftest')) {
  const { mineLexicon, trCommentary } = await import('./chok-comm-translit.mjs');
  const pairs = function* (lang) {
    for (const { file } of L.parashaList()) {
      const he = L.loadBundle(file)._comm, tv = L.loadBundle(file, lang)._comm;
      for (const [id, o] of Object.entries(he)) for (const w of ['rashi', 'targum', 'ohc']) {
        if (!o[w] || !tv[id] || !tv[id][w] || o[w].length !== tv[id][w].length) continue;
        for (let i = 0; i < o[w].length; i++) yield [o[w][i], tv[id][w][i]];
      }
    }
  };
  if (process.argv.includes('--mine-lexicon')) {
    const lex = mineLexicon((l) => [...pairs(l)]);
    console.log('lexicon entries', Object.fromEntries(Object.entries(lex).map(([k, v]) => [k, Object.keys(v).length])));
  } else {
    for (const lang of L.LANGS) {
      let n = 0, exact = 0, w = 0, ok = 0;
      const norm = (s) => s.split(/\s+/).filter(Boolean);
      for (const [h, v] of pairs(lang)) {
        if (++n % 5) continue;
        const o = trCommentary(lang, h); if (o === v) exact++;
        const a = norm(o), b = norm(v); if (a.length === b.length) a.forEach((x, i) => { w++; if (x === b[i]) ok++; });
      }
      console.log(lang, 'word match', (100 * ok / w).toFixed(1) + '%', 'exact paragraphs', (100 * exact / (n / 5)).toFixed(1) + '%');
    }
  }
  process.exit(0);
}

// -------- 1. what is missing --------
const NEEDED = new Map();           // "w|book|chapter"
const todo = [];                    // {file, id, w, book, c, v}
for (const { name, file } of L.parashaList()) {
  if (only && file !== only) continue;
  const cm = L.loadBundle(file)._comm || {};
  for (const id of L.universe(name).keys()) {
    const book = id.replace(/ \d+:\d+$/, '');
    const [c, v] = id.split(' ').pop().split(':').map(Number);
    for (const w of L.sourcesFor(book)) {
      if (cm[id] && cm[id][w]) continue;
      NEEDED.set(`${w}|${book}|${c}`, 1);
      todo.push({ file, id, w, book, c, v });
    }
  }
}
console.log(`${todo.length} (verse, source) pairs lack an entry; fetching ${NEEDED.size} Sefaria chapters ...`);
const keys = [...NEEDED.keys()], fetched = new Map();
let next = 0;
await Promise.all(Array.from({ length: 4 }, async () => {
  while (next < keys.length) {
    const k = next++; const [w, book, c] = keys[k].split('|');
    fetched.set(keys[k], await L.sefariaChapter(w, book, +c));
    if (next % 200 === 0) console.log(`  ${next}/${keys.length}`);
  }
}));

// verses the primary version lacks: ask for the single verse (Rashi / Targum only)
const fallback = new Map(); let fbNext = 0, fbUsed = {};
const fbTodo = [...new Map(todo.filter((t) => ['rashi', 'targum'].includes(t.w) && !fetched.get(`${t.w}|${t.book}|${t.c}`).verses.has(t.v)).map((t) => [`${t.w}|${t.id}`, t])).values()];
console.log(`${fbTodo.length} verse-level fallback lookups ...`);
await Promise.all(Array.from({ length: 4 }, async () => {
  while (fbNext < fbTodo.length) {
    const t = fbTodo[fbNext++];
    fallback.set(`${t.w}|${t.id}`, await L.sefariaVerse(t.w, t.book, t.c, t.v));
    if (fbNext % 200 === 0) console.log(`  ${fbNext}/${fbTodo.length}`);
  }
}));

// -------- 2. build the additions --------
const tagCensus = {};
function cleanNew(p) {
  // the bundles only ever carry <b>..</b>: other markup Sefaria has added since (footnote <small>, <sup>, <i>, <br>) is dropped, its text kept
  return p.replace(/<(\/?)([a-zA-Z]+)[^>]*>/g, (all, sl, t) => { tagCensus[t.toLowerCase()] = (tagCensus[t.toLowerCase()] || 0) + 1; return t.toLowerCase() === 'b' ? `<${sl}b>` : ' '; })
    .replace(/\s{2,}/g, ' ').replace(/\s+([.,:;])/g, '$1').trim();
}
const add = new Map();              // file -> Map(id -> {w: [paras]})
const stat = {}, noneStat = {};
for (const t of todo) {
  let got = fetched.get(`${t.w}|${t.book}|${t.c}`).verses.get(t.v);
  const key = `${t.book}|${t.w}`;
  if (!got && fallback.get(`${t.w}|${t.id}`)) { const f = fallback.get(`${t.w}|${t.id}`); got = f.paras; fbUsed[`${t.id}|${t.w}|${f.version}`] = 1; }
  if (!got) { noneStat[key] = (noneStat[key] || 0) + 1; continue; }
  let paras = got.map(cleanNew).filter(Boolean);
  if (t.w === 'rashi' && L.TORAH_BOOKS.has(t.book)) {
    const verse = L.TORAH[t.book][t.c - 1][t.v - 1][0];
    paras = paras.map((p) => L.vocalizeDH(p, [verse]));
  }
  if (!paras.length) continue;
  if (!add.has(t.file)) add.set(t.file, new Map());
  const m = add.get(t.file); if (!m.has(t.id)) m.set(t.id, {});
  m.get(t.id)[t.w] = paras;
  stat[key] = (stat[key] || 0) + 1;
}
const sum = (o) => Object.values(o).reduce((a, b) => a + b, 0);
console.log('\nADDED (entries) per book|source:'); for (const [k, v] of Object.entries(stat).sort()) console.log(' ', k, v);
console.log('total added', sum(stat), 'in', add.size, 'bundles');
console.log('\nSTILL ABSENT because Sefaria has nothing (verse-source pairs, counted per bundle):'); for (const [k, v] of Object.entries(noneStat).sort()) console.log(' ', k, v);
console.log('tags seen in new text:', tagCensus);
console.log('filled from another Sefaria version (verse-level fallback):', Object.keys(fbUsed));
if (!WRITE) { console.log('\n(dry run - pass --write)'); process.exit(0); }

// -------- 3. write --------
const { trCommentary } = await import('./chok-comm-translit.mjs');
const TR_SRC = new Set(['rashi', 'targum', 'ohc']);
const rank = (k) => { const i = L.SRC_ORDER.indexOf(k); return i < 0 ? -1 : i; };
function merge(cm, id, add1, translate) {
  const cur = cm[id] || {};
  const nu = {};
  Object.keys(cur).forEach((k) => { nu[k] = cur[k]; });
  for (const [w, paras] of Object.entries(add1)) {
    if (w in cur) continue;                                      // never overwrite
    if (translate && !TR_SRC.has(w)) continue;                   // Metzudot stay Hebrew-only
    nu[w] = translate ? paras.map((p) => trCommentary(translate, p)) : paras;
  }
  // canonical source order, unknown keys (bart ...) keep their place in front
  const keys = Object.keys(nu).sort((a, b) => rank(a) - rank(b));
  const o = {}; keys.forEach((k) => { o[k] = nu[k]; });
  cm[id] = o;
}
const changedFiles = [];
for (const [file, m] of add) {
  for (const lang of ['he', ...L.LANGS]) {
    const { obj, style } = L.readBundleRaw(file, lang === 'he' ? undefined : lang);
    obj._comm = obj._comm || {};
    let touched = false;
    for (const [id, a] of m) {
      const before = JSON.stringify(obj._comm[id] || null);
      merge(obj._comm, id, a, lang === 'he' ? null : lang);
      if (JSON.stringify(obj._comm[id]) !== before) touched = true;
    }
    if (touched) { L.writeBundle(file, lang === 'he' ? undefined : lang, obj, style); changedFiles.push(L.bundlePath(file, lang === 'he' ? undefined : lang)); }
  }
}
fs.writeFileSync('/tmp/chok-comm-changed.json', JSON.stringify(changedFiles));
console.log('written', changedFiles.length, 'files');
