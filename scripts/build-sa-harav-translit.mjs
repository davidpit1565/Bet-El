#!/usr/bin/env node
// Generate the phonetic transliteration of Shulchan Aruch HaRav (Orach Chayim) from the vocalized
// Hebrew in data/sa-harav/oc/<n>.json, deterministically (no LLM, no network):
//
//   node scripts/build-sa-harav-translit.mjs --lang en [--only 1,8,100] [--report stats.json]
//
// Output: data/sa-harav/oc/<n>.<lang>.json with the same shape as the Hebrew file ({n, t, s:[...]}),
// <b>..</b> markers preserved. Transliteration ONLY - never translation. The language module lives in
// scripts/translit/<lang>.mjs (see scripts/translit/README.md for how to add one).
//
// After generating, re-run `node scripts/generate-data-manifest.mjs` (new files under data/).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { transliterate, newStats } from './translit/core.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const arg = (n, d) => { const i = args.indexOf('--' + n); return i >= 0 ? args[i + 1] : d; };
const lang = arg('lang', 'en');
const only = arg('only', '') ? new Set(arg('only').split(',').map(Number)) : null;
const reportPath = arg('report', '');
const dir = path.join(ROOT, 'data/sa-harav/oc');

const mod = await import(pathToFileURL(path.join(ROOT, 'scripts/translit', `${lang}.mjs`)).href);
const scheme = mod.scheme || mod.default;
if (!scheme) throw new Error(`scripts/translit/${lang}.mjs must export a scheme`);

const stats = newStats();
let files = 0, bytes = 0, hebBytes = 0;
const nums = fs.readdirSync(dir).filter((f) => /^\d+\.json$/.test(f)).map((f) => parseInt(f, 10)).sort((a, b) => a - b);
for (const n of nums) {
  if (only && !only.has(n)) continue;
  const raw = fs.readFileSync(path.join(dir, `${n}.json`), 'utf8');
  const d = JSON.parse(raw);
  const tr = (s) => transliterate(s, scheme, stats).out.normalize('NFC');
  const out = { n: d.n, t: tr(d.t), s: d.s.map(tr) };
  const json = JSON.stringify(out);
  fs.writeFileSync(path.join(dir, `${n}.${lang}.json`), json);
  files++; bytes += Buffer.byteLength(json); hebBytes += Buffer.byteLength(raw);
}

const top = (m, k = 25) => [...m.entries()].sort((a, b) => b[1] - a[1]).slice(0, k);
const rep = {
  lang, files, words: stats.words, byKind: stats.byKind,
  unvocalizedWords: stats.unvocalized, abbreviationsOrNumerals: stats.abbrev, singleLetters: stats.letters,
  partiallyVocalizedWords: stats.defective,
  unknownCharacters: [...stats.unknownChars.entries()],
  topUnvocalized: top(stats.unvocWords), topPartiallyVocalized: top(stats.defWords),
  outputBytes: bytes, outputMB: +(bytes / 1048576).toFixed(2), hebrewMB: +(hebBytes / 1048576).toFixed(2),
};
console.log(JSON.stringify(rep, null, 1));
if (reportPath) fs.writeFileSync(reportPath, JSON.stringify(rep, null, 1));
