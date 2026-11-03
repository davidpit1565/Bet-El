#!/usr/bin/env node
/* Audit data/chok-daf-c/*.json against data/chok-daf/*.json for every daf-side:
 * segment count vs Steinsaltz / Rashi entry counts, and a per-entry alignment
 * test (which neighbouring Hebrew segment g[i+off], off in -2..2, the entry's
 * words overlap most). Prints a length-diff histogram and every side whose
 * entries sit at a non-zero offset for 2+ entries in a row ("drift").
 * Usage: node scripts/audit-daf-steinsaltz.mjs [--list]
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const words = (s) => new Set(String(s || '').replace(/<[^>]+>/g, ' ').replace(/[֑-ׇ]/g, '')
  .replace(/[^א-ת ]/g, ' ').split(/\s+/).filter((w) => w.length > 2));
const ov = (a, b) => { const A = words(a), B = words(b); if (!A.size || !B.size) return 0; let n = 0; for (const w of A) if (B.has(w)) n++; return n / Math.min(A.size, B.size); };
const hist = {}, rhist = {}, drift = []; let sides = 0;
for (const f of fs.readdirSync(path.join(ROOT, 'data/chok-daf-c')).filter((x) => /^\d+\.json$/.test(x))) {
  const c = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/chok-daf-c', f), 'utf8'));
  const h = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/chok-daf', f), 'utf8'));
  for (const k of Object.keys(c)) for (const side of ['a', 'b']) {
    const g = ((h[k] || {}).g || {})[side]; if (!g) continue;
    const st = (c[k].steinsaltz || {})[side], ra = (c[k].rashi || {})[side];
    sides++;
    if (st) { const d = st.length - g.length; hist[d] = (hist[d] || 0) + 1; }
    if (ra) { const d = ra.length - g.length; rhist[d] = (rhist[d] || 0) + 1; }
    if (!st) continue;
    const offs = st.map((x, i) => {
      if (!x) return null;
      let best = 0, bs = ov(x, g[i]);
      for (const o of [-2, -1, 1, 2]) { const j = i + o; if (j < 0 || j >= g.length) continue; const s = ov(x, g[j]); if (s > bs + 0.25) { bs = s; best = o; } }
      return bs >= 0.5 ? best : null;
    });
    let run = 0, runOff = 0, start = 0, flagged = false;
    offs.forEach((o, i) => {
      if (o && o === runOff) run++; else { run = o ? 1 : 0; runOff = o || 0; start = i; }
      if (run >= 2 && !flagged) { flagged = true; drift.push(`${f} key ${k}${side} from idx ${start} offset ${runOff} (g=${g.length} st=${st.length})`); }
    });
  }
}
console.log('daf-sides audited:', sides);
console.log('steinsaltz.length - segments.length histogram:', JSON.stringify(hist));
console.log('rashi.length - segments.length histogram:', JSON.stringify(rhist));
console.log('sides with drifted alignment:', drift.length);
if (process.argv.includes('--list')) drift.forEach((x) => console.log('  ', x));
