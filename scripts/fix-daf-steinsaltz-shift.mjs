#!/usr/bin/env node
/* Fix the Steinsaltz commentary shift in data/chok-daf-c/<blk>.json.
 *
 * The Hebrew daf text (data/chok-daf/<blk>.json, rec.g[side][i]) contains a
 * "Hadran" divider segment ("הדרן עלך ...") that has no Steinsaltz entry in the
 * source, so in some daf-sides every steinsaltz[side][j] after the divider sits
 * one slot too early (it explains g[j+1]). The reader looks the commentary up by
 * the same index (ckDafCommFor), so it shows under the wrong segment.
 *
 * Fix: insert '' into steinsaltz[side] at the Hadran segment's index. Whether a
 * side needs it is decided by word-overlap between each entry and the Hebrew
 * segment it would sit under, before vs. after the insertion. Idempotent: once
 * aligned, the shifted score no longer beats the aligned one, so a second run
 * changes nothing.
 *
 * Usage: node scripts/fix-daf-steinsaltz-shift.mjs [--dry] [--verbose]
 * Prints the paths it changed (one per line, "CHANGED data/chok-daf-c/N.json")
 * and the list of undecided Hadran positions for hand checking.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CDIR = path.join(ROOT, 'data/chok-daf-c');
const HDIR = path.join(ROOT, 'data/chok-daf');
const DRY = process.argv.includes('--dry');
const VERBOSE = process.argv.includes('--verbose');

const words = (s) => new Set(
  String(s || '').replace(/<[^>]+>/g, ' ').replace(/[֑-ׇ]/g, '')
    .replace(/[^א-ת ]/g, ' ').split(/\s+/).filter((w) => w.length > 2));
const overlap = (a, b) => {
  const A = words(a), B = words(b);
  if (!A.size || !B.size) return 0;
  let n = 0; for (const w of A) if (B.has(w)) n++;
  return n / Math.min(A.size, B.size);
};
/* segments the source gives no Steinsaltz entry: the Hadran divider and the
   "(סימן: ...)" mnemonic line */
const plain = (t) => String(t).replace(/<[^>]+>/g, '').replace(/[\u0591-\u05C7]/g, '').trim();
const isHadran = (t) => { const p = plain(t); return /^הדרן\s+על/.test(p) || (p.length < 120 && /(^\(?\s*סימן|סימן[\s.:)״"]*$)/.test(p)); };

/* decide for the Hadran at index h whether to insert. region = [h, end) */
export function decide(g, st, h, end) {
  if (h >= st.length) return { act: 'none', why: 'nothing after divider' };
  if (st[h] === '') return { act: 'none', why: 'already blank' };
  let s0 = 0, s1 = 0, n = 0;
  for (let i = h; i < Math.min(st.length, end); i++) {
    if (!st[i]) continue;
    s0 += overlap(st[i], g[i]);
    if (i + 1 < g.length) s1 += overlap(st[i], g[i + 1]);
    n++;
  }
  const r = { s0: +s0.toFixed(2), s1: +s1.toFixed(2), n };
  if (s1 > s0 * 1.3 + 1 || (n <= 2 && s0 === 0 && s1 >= 0.7) || (s1 > s0 * 1.3 && s1 - s0 >= 0.9)) return { act: 'insert', ...r };
  if (s1 > s0 * 1.3 || (s1 > s0 && s1 > 0.5)) return { act: 'undecided', ...r };
  return { act: 'none', ...r };
}

const files = fs.readdirSync(CDIR).filter((f) => /^\d+\.json$/.test(f))
  .sort((a, b) => parseInt(a) - parseInt(b));
/* the files are Python json.dumps(ensure_ascii=False) output (", " and ": ");
   keep that exact layout so the diff only shows the inserted blanks */
const dump = (v) => Array.isArray(v) ? '[' + v.map(dump).join(', ') + ']'
  : (v && typeof v === 'object') ? '{' + Object.keys(v).map((k) => JSON.stringify(k) + ': ' + dump(v[k])).join(', ') + '}'
  : JSON.stringify(v);
let sides = 0, changed = 0; const undecided = [], inserted = [];
for (const f of files) {
  const raw = fs.readFileSync(path.join(CDIR, f), 'utf8');
  const c = JSON.parse(raw);
  if (dump(c) !== raw) throw new Error(f + ': serializer does not round-trip, refusing to write');
  const h =JSON.parse(fs.readFileSync(path.join(HDIR, f), 'utf8'));
  let dirty = false;
  for (const k of Object.keys(c)) {
    for (const side of ['a', 'b']) {
      const g = ((h[k] || {}).g || {})[side];
      const st = (c[k].steinsaltz || {})[side];
      if (!g || !st) continue;
      const hs = g.map((t, i) => (isHadran(t) ? i : -1)).filter((i) => i >= 0);
      for (let q = 0; q < hs.length; q++) {
        const end = q + 1 < hs.length ? hs[q + 1] + 1 : g.length; // st indices are shifted by earlier inserts, region ends at next divider
        const d = decide(g, st, hs[q], end);
        const tag = `${f} key ${k}${side} idx ${hs[q]} (g=${g.length} st=${st.length})`;
        if (d.act === 'insert') {
          st.splice(hs[q], 0, ''); dirty = true; sides++;
          inserted.push(`${tag} ${d.s0}->${d.s1}`);
        } else if (d.act === 'undecided') undecided.push(`${tag} s0=${d.s0} s1=${d.s1} n=${d.n}`);
        else if (VERBOSE) console.log('skip', tag, JSON.stringify(d));
      }
    }
  }
  if (dirty) {
    changed++;
    console.log('CHANGED data/chok-daf-c/' + f);
    if (!DRY) fs.writeFileSync(path.join(CDIR, f), dump(c));
  }
}
console.log(`inserted ${sides} blanks in ${changed} files${DRY ? ' (dry)' : ''}`);
for (const x of inserted) console.log('  INS', x);
for (const x of undecided) console.log('  UNDECIDED', x);
