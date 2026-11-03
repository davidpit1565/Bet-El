#!/usr/bin/env node
/* Verifies the Avinu Malkeinu transliterations line-by-line against the
 * Hebrew in data/siddur.json: same line count, every line starts with the
 * language's "Avinu malkenu" opener, and the per-line length profile follows
 * the Hebrew's (Pearson r >= 0.85 and no line whose length ratio is > 2.2x off
 * the median) - a one-line shift of the long lines (kalle deber..., satom piyot)
 * breaks that immediately. Exit 1 on any failure.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const rd = (p) => JSON.parse(fs.readFileSync(path.join(ROOT, p), 'utf8'));
const he = rd('data/siddur.json').avinuMalkeinu;
const heLen = he.map((l) => l.replace(/[^א-ת]/g, '').length);
const OPEN = { en: /^Abinu malkenu, /, fr: /^Abinou malkenou /, ru: /^Авину малкену, /, ka: /^ავინუ მალქენუ / };
const pearson = (x, y) => {
  const n = x.length, mx = x.reduce((a, b) => a + b) / n, my = y.reduce((a, b) => a + b) / n;
  let sxy = 0, sxx = 0, syy = 0;
  for (let i = 0; i < n; i++) { sxy += (x[i] - mx) * (y[i] - my); sxx += (x[i] - mx) ** 2; syy += (y[i] - my) ** 2; }
  return sxy / Math.sqrt(sxx * syy);
};
let bad = 0;
console.log('he:', he.length, 'lines');
for (const lang of Object.keys(OPEN)) {
  const t = rd(`data/prayers-${lang}.json`).avinuMalkeinu;
  const errs = [];
  if (t.length !== he.length) errs.push(`line count ${t.length} != ${he.length}`);
  else {
    t.forEach((l, i) => { if (!OPEN[lang].test(l)) errs.push(`line ${i} lacks opener: ${l.slice(0, 40)}`); });
    const tl = t.map((l) => l.length);
    const r = pearson(heLen, tl);
    const ratios = tl.map((v, i) => v / heLen[i]).sort((a, b) => a - b);
    const med = ratios[Math.floor(ratios.length / 2)];
    tl.forEach((v, i) => { const q = v / heLen[i] / med; if (q > 2.2 || q < 1 / 2.2) errs.push(`line ${i} length ratio off (${q.toFixed(2)}x)`); });
    if (r < 0.85) errs.push(`length correlation ${r.toFixed(3)} < 0.85`);
    console.log(lang + ':', t.length, 'lines, length correlation with Hebrew', r.toFixed(3));
  }
  if (errs.length) { bad++; console.log(lang, 'FAIL'); errs.forEach((e) => console.log('   ', e)); }
}
console.log(bad ? 'FAILED' : 'OK: all four languages aligned line by line');
process.exit(bad ? 1 : 0);
