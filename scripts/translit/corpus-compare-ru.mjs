#!/usr/bin/env node
// Match rate of ru.mjs against corpus-ru.json (dialect A entries).
//   node scripts/translit/corpus-compare-ru.mjs [--show 60] [--dialect A] [--opts JSON]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createScheme } from './ru.mjs';
import { transliterate, newStats } from './core.mjs';

const dir = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const arg = (n, d) => { const i = args.indexOf('--' + n); return i >= 0 ? args[i + 1] : d; };
const scheme = createScheme(JSON.parse(arg('opts', '{}')));
const dial = arg('dialect', 'A');
const corpus = JSON.parse(fs.readFileSync(path.join(dir, 'corpus-ru.json'), 'utf8')).filter((e) => e.dialect === dial);
const norm = (s) => s.toLowerCase().replace(/[^а-яё-]/g, '');
let m = 0; const bad = [];
for (const e of corpus) {
  const got = transliterate(e.he, scheme, newStats()).out;
  if (norm(got) === norm(e.ru)) m++; else bad.push(`${e.he}\t${norm(got)}\t${norm(e.ru)}\t${e.src}`);
}
console.log(`dialect ${dial}: ${m}/${corpus.length} = ${(100 * m / corpus.length).toFixed(2)}%`);
bad.slice(0, +arg('show', 60)).forEach((b) => console.log(b));
