#!/usr/bin/env node
// Print aligned Hebrew=Russian word pairs for a siman for manual spot-reading.
//   node scripts/translit/sample-ru.mjs <siman> [skipWords=40] [count=75]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { scheme } from './ru.mjs';
import { transliterate, newStats } from './core.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const [n, skip = 40, count = 75] = process.argv.slice(2).map(Number);
const d = JSON.parse(fs.readFileSync(path.join(root, 'data/sa-harav/oc', `${n}.json`), 'utf8'));
const words = d.s.join(' ').replace(/<[^>]*>/g, '').split(/\s+/).filter((w) => /[א-ת]/.test(w)).slice(skip, skip + count);
console.log(`siman ${n}`);
console.log(words.map((w) => `${w}=${transliterate(w, { ...scheme, postText: (s) => s }, newStats()).out}`).join('  '));
