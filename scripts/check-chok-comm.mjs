#!/usr/bin/env node
// Validation for the Chok LeYisrael commentary bundles (companion of scripts/build-chok-comm.mjs).
//
//   node scripts/check-chok-comm.mjs [--baseline <git-ref>]
//
// For every verse of every torah / tzeruf / neviim / ketuvim list of every parasha bundle it asserts:
//   * a `_comm` entry exists for every source Sefaria has (chapter request, or the verse-level fallback for verses
//     the primary version lacks) - "gaps" below; --baseline prints the same count for an older commit (before/after)
//   * no entry holds an empty source / empty paragraph (a button that would open nothing)
//   * every variant (en/fr/ru/ka) has exactly the Hebrew's `_comm` ids and, for rashi/targum/ohc, the same number of
//     paragraphs per source; no Metzudat entries in a variant; no corrupted HTML entities (&нбсп; &Nbsp; ...)
//   * every file is valid JSON in a layout the writers reproduce byte for byte
// Exits non-zero on any violation.
import { execFileSync } from 'node:child_process';
import * as L from './chok-comm-lib.mjs';

const bi = process.argv.indexOf('--baseline');
const baseline = bi >= 0 ? process.argv[bi + 1] : null;
const gitLoad = (file) => JSON.parse(execFileSync('git', ['show', `${baseline}:${L.bundlePath(file)}`], { cwd: L.ROOT, maxBuffer: 1 << 28 }).toString());

const errors = [];
const fail = (m) => { if (errors.length < 60) errors.push(m); errors.count = (errors.count || 0) + 1; };

async function gaps(loadHe) {
  const out = {}; let total = 0, have = 0;
  for (const { name, file } of L.parashaList()) {
    const cm = loadHe(file)._comm || {};
    for (const id of L.universe(name).keys()) {
      const book = id.replace(/ \d+:\d+$/, '');
      const [c, v] = id.split(' ').pop().split(':').map(Number);
      for (const w of L.sourcesFor(book)) {
        if (cm[id] && cm[id][w]) { have++; continue; }
        let avail = (await L.sefariaChapter(w, book, c)).verses.has(v);
        if (!avail && ['rashi', 'targum'].includes(w)) avail = !!(await L.sefariaVerse(w, book, c, v));
        if (avail) { const k = `${book}|${w}`; out[k] = (out[k] || 0) + 1; total++; }
      }
    }
  }
  return { out, total, have };
}

// ---- structure checks ----
const ENT = /&[^\x00-\x7F][^;\s<]{0,12};|&[A-Z][A-Za-z]*;/;
for (const { name, file } of L.parashaList()) {
  let he;
  try { he = L.readBundleRaw(file).obj; } catch (e) { fail(`${file}: ${e.message}`); continue; }
  const cm = he._comm || {};
  for (const [id, o] of Object.entries(cm)) for (const [w, ps] of Object.entries(o)) {
    if (!Array.isArray(ps) || !ps.length || ps.some((p) => typeof p !== 'string' || !p.trim())) fail(`${file} ${id} ${w}: empty source/paragraph`);
  }
  for (const lang of L.LANGS) {
    let v;
    try { v = L.readBundleRaw(file, lang).obj; } catch (e) { fail(`${file}.${lang}: ${e.message}`); continue; }
    const vc = v._comm || {};
    for (const id of Object.keys(cm)) if (!vc[id] && Object.keys(cm[id]).some((w) => ['rashi', 'targum', 'ohc'].includes(w))) fail(`${file}.${lang}: missing id ${id}`);
    for (const [id, o] of Object.entries(vc)) {
      if (!cm[id]) { fail(`${file}.${lang}: extra id ${id}`); continue; }
      for (const [w, ps] of Object.entries(o)) {
        if (w === 'mdavid' || w === 'mzion') fail(`${file}.${lang} ${id}: Metzudat in a variant`);
        if (!cm[id][w]) fail(`${file}.${lang} ${id} ${w}: not in Hebrew`);
        else if (cm[id][w].length !== ps.length) fail(`${file}.${lang} ${id} ${w}: paragraph count ${ps.length} != ${cm[id][w].length}`);
      }
      for (const w of ['rashi', 'targum', 'ohc']) if (cm[id][w] && !o[w]) fail(`${file}.${lang} ${id} ${w}: no variant entry`);
    }
    if (ENT.test(JSON.stringify(v))) fail(`${file}.${lang}: corrupted HTML entity`);
  }
  if (ENT.test(JSON.stringify(he))) fail(`${file}: corrupted HTML entity`);
}

// ---- coverage vs Sefaria ----
const now = await gaps((f) => L.loadBundle(f));
console.log('coverage vs Sefaria (verse-source pairs per bundle):');
if (baseline) {
  const before = await gaps(gitLoad);
  console.log(`  BEFORE (${baseline}): present ${before.have}, gaps where Sefaria has the text ${before.total}`);
  for (const [k, n] of Object.entries(before.out).sort()) console.log('    ', k, n);
}
console.log(`  AFTER: present ${now.have}, gaps where Sefaria has the text ${now.total}`);
for (const [k, n] of Object.entries(now.out).sort()) { console.log('    ', k, n); fail(`gap ${k}: ${n}`); }

if (errors.length) { console.log(`\nFAILED (${errors.count} problems), first ${errors.length}:`); errors.forEach((e) => console.log(' -', e)); process.exit(1); }
console.log('\nOK: no gaps, no variant drift, no corrupted entities, all JSON valid');
