#!/usr/bin/env node
// Compare the rule-based English transliterator against the app's existing (human/LLM) transliteration.
//
//   node scripts/translit/corpus-compare.mjs [--opts '{"bSoft":"b"}'] [--show 60] [--corpus torah,bic,daf]
//
// Corpora (Hebrew with nikud, aligned word by word to the existing English):
//   torah : data/torah-data.json[book][ch][v][0]  vs data/torah-en.json
//   bic   : data/chok-benishchai/**/<unit>.json (intro + days[][].paragraphs) vs <unit>.fr.json
//   daf   : data/chok-daf/<n>.json (Mishnah/Gemara, nikud) vs <n>.fr.json
// Paragraphs whose Hebrew/English word counts differ are skipped (counted). Unvocalized Hebrew words
// are excluded from the match rate (nothing to match against). Comparison is case-insensitive and
// ignores punctuation and apostrophes.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createScheme } from './fr.mjs';
import { parseWord, tokenize, transliterate, newStats } from './core.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const args = process.argv.slice(2);
const arg = (n, d) => { const i = args.indexOf('--' + n); return i >= 0 ? args[i + 1] : d; };
const opts = JSON.parse(arg('opts', '{}'));
const show = +arg('show', 50);
const which = arg('corpus', 'torah,bic,daf,siddur').split(',');
const scheme = createScheme(opts);
const rd = (p) => JSON.parse(fs.readFileSync(path.join(ROOT, p), 'utf8'));

function* torahPairs() {
  const he = rd('data/torah-data.json'), en = rd('data/torah-fr.json');
  for (const book of Object.keys(en)) {
    if (!Array.isArray(en[book]) || !he[book]) continue;
    for (let c = 0; c < en[book].length; c++) for (let v = 0; v < en[book][c].length; v++) {
      const h = he[book][c] && he[book][c][v] && he[book][c][v][0]; const e = en[book][c][v] && en[book][c][v][0];
      if (typeof h === 'string' && typeof e === 'string') yield [h, e];
    }
  }
}
function* bicPairs() {
  for (const yr of ['year1', 'year2']) {
    const dir = path.join(ROOT, 'data/chok-benishchai', yr);
    for (const f of fs.readdirSync(dir)) {
      if (!f.endsWith('.json') || /\.(en|fr|ru|ka)\.json$/.test(f)) continue;
      const hp = path.join(dir, f), ep = path.join(dir, f.replace(/\.json$/, '.fr.json'));
      if (!fs.existsSync(ep)) continue;
      const h = JSON.parse(fs.readFileSync(hp, 'utf8')), e = JSON.parse(fs.readFileSync(ep, 'utf8'));
      for (let k = 0; k < (h.intro || []).length; k++) if (e.intro && e.intro[k]) yield [h.intro[k], e.intro[k]];
      for (let d = 0; d < (h.days || []).length; d++) for (let j = 0; j < h.days[d].length; j++) {
        const hi = h.days[d][j], ei = e.days && e.days[d] && e.days[d][j];
        if (!ei) continue;
        for (let k = 0; k < hi.paragraphs.length; k++) if (ei.paragraphs[k]) yield [hi.paragraphs[k], ei.paragraphs[k]];
      }
    }
  }
}
function* dafPairs() {
  const dir = path.join(ROOT, 'data/chok-daf');
  const walk = function* (h, e) {
    if (Array.isArray(h)) { for (let i = 0; i < h.length; i++) { if (typeof h[i] === 'string') { if (typeof e[i] === 'string') yield [h[i], e[i]]; } else if (e && e[i]) yield* walk(h[i], e[i]); } }
    else if (h && typeof h === 'object') for (const k of Object.keys(h)) if (e && e[k] !== undefined) yield* walk(h[k], e[k]);
  };
  for (const f of fs.readdirSync(dir)) {
    if (!/^\d+\.json$/.test(f)) continue;
    const ep = path.join(dir, f.replace('.json', '.fr.json'));
    if (!fs.existsSync(ep)) continue;
    yield* walk(JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')), JSON.parse(fs.readFileSync(ep, 'utf8')));
  }
}

function* siddurPairs() {
  const he = rd('data/siddur.json'), en = rd('data/prayers-en.json');
  const walk = function* (h, e) {
    if (typeof h === 'string' && typeof e === 'string') { yield [h, e]; return; }
    if (Array.isArray(h) && Array.isArray(e)) { for (let i = 0; i < h.length; i++) yield* walk(h[i], e[i]); return; }
    if (h && e && typeof h === 'object' && typeof e === 'object') for (const k of Object.keys(h)) if (k in e) yield* walk(h[k], e[k]);
  };
  for (const k of Object.keys(he)) if (k in en) yield* walk(he[k], en[k]);
}
const norm = (s) => s.normalize('NFC').toLowerCase().replace(/[^\p{L}-]/gu, '');
const HEB = /[א-ת]/;
const clean = (s) => s.replace(/<[^>]*>/g, ' ');
const results = {};
const diffs = new Map();
for (const name of which) {
  const gen = { torah: torahPairs, bic: bicPairs, daf: dafPairs, siddur: siddurPairs }[name];
  const r = { paras: 0, skipped: 0, words: 0, match: 0, skippedNoNikud: 0 };
  for (const [h0, e0] of gen()) {
    r.paras++;
    const hw = clean(h0).split(/\s+/).filter((t) => HEB.test(t));
    const ew = clean(e0).split(/\s+/).filter((t) => /\p{L}/u.test(t));
    if (hw.length !== ew.length) { r.skipped++; continue; }
    for (let i = 0; i < hw.length; i++) {
      if (/[\u05F3\u05F4'"]/.test(hw[i])) { r.skippedNoNikud++; continue; }
      const toks = tokenize(hw[i]).filter((t) => t.t === 'w');
      if (!toks.length) continue;
      // unvocalized -> excluded
      if (toks.every((t) => !/[ְ-ֻ]/.test(t.s))) { r.skippedNoNikud++; continue; }
      const ours = transliterate(hw[i], scheme, newStats()).out;
      r.words++;
      if (norm(ours) === norm(ew[i])) r.match++;
      else {
        const k = `${hw[i].normalize('NFC')}\t${ours}\t${ew[i]}`;
        diffs.set(k, (diffs.get(k) || 0) + 1);
      }
    }
  }
  results[name] = r;
  console.log(name, JSON.stringify(r), 'match=' + (100 * r.match / r.words).toFixed(2) + '%');
}
const tot = Object.values(results).reduce((a, r) => ({ w: a.w + r.words, m: a.m + r.match }), { w: 0, m: 0 });
console.log('TOTAL', tot.w, 'words', 'match=' + (100 * tot.m / tot.w).toFixed(2) + '%');
const top = [...diffs.entries()].sort((a, b) => b[1] - a[1]).slice(0, show);
for (const [k, n] of top) console.log(n + '\t' + k);
if (args.includes('--dump')) fs.writeFileSync(arg('dump', '/dev/null'), [...diffs.entries()].sort((a, b) => b[1] - a[1]).map(([k, n]) => n + '\t' + k).join('\n'));
