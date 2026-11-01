#!/usr/bin/env node
// Match rate of fr.mjs against corpus-fr.json (word-aligned existing French transliteration).
//   node scripts/translit/corpus-fr-compare.mjs [--conv A] [--show 80] [--dump out.json]
// Comparison is case-insensitive and ignores punctuation.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { scheme } from './fr.mjs';
import { transliterate, newStats } from './core.mjs';
const dir = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const arg = (n, d) => { const i = args.indexOf('--' + n); return i >= 0 ? args[i + 1] : d; };
const conv = arg('conv', 'A'), show = +arg('show', 80);
const corpus = JSON.parse(fs.readFileSync(path.join(dir, 'corpus-fr.json'), 'utf8')).filter((e) => e.conv === conv);
const norm = (s) => s.normalize('NFC').toLowerCase().replace(/[^\p{L}-]/gu, '');
let ok = 0; const bad = []; const outs = [];
for (const e of corpus) {
  const ours = transliterate(e.he, scheme, newStats()).out;
  outs.push({ he: e.he, ours });
  if (norm(ours) === norm(e.fr)) ok++; else bad.push(`${e.he}\tours=${ours}\texisting=${e.fr}\t[${e.tag}]`);
}
console.log(`conv ${conv}: ${ok}/${corpus.length} = ${(100 * ok / corpus.length).toFixed(1)}%`);
bad.slice(0, show).forEach((b) => console.log(b));
if (arg('dump', '')) fs.writeFileSync(arg('dump'), JSON.stringify(outs));
