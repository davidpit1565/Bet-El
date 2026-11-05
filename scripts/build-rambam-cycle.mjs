#!/usr/bin/env node
// Rebuilds the 'rambam' section of data/chok-cycles.json (order + official cycle parameters) AND re-keys the
// data/chok-rambam/<block>[.<lang>].json block files so that block b always holds exactly the refs of
// order[b*40 .. b*40+39] (the app looks text up by block index, see ckBlockOf / CYC_BLOCK['rambam/'+b]).
//
// ROOT CAUSE this script prevents: the original order was sorted ALPHABETICALLY by Sefaria's English book titles
// ("Admission into the Sanctuary" first ... "Woman Suspected of Infidelity" last) instead of Mishneh Torah order,
// so the daily Rambam did not match the official Daily Rambam. The true order is Sefaria's table of contents
// (https://www.sefaria.org/api/index, category "Mishneh Torah", Introduction excluded) - NEVER sort the titles.
//
// Usage:  node scripts/build-rambam-cycle.mjs            (dry run: verifies, writes nothing)
//         node scripts/build-rambam-cycle.mjs --apply    (writes blocks first, then chok-cycles.json, via temp+rename)
//         add --cycles-out FILE --blocks-out DIR to stage elsewhere instead of in place.
// After applying: bump data/data-version.json for data/chok-cycles.json and every data/chok-rambam/* file, and
// run node scripts/check-rambam-cycle.mjs.
import { readFileSync, writeFileSync, renameSync, readdirSync, mkdirSync } from 'fs';
import { join } from 'path';
const root = new URL('..', import.meta.url).pathname;
const args = process.argv.slice(2);
const opt = n => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : null; };
const apply = args.includes('--apply');
const cyclesIn = join(root, 'data/chok-cycles.json');
const blocksDir = join(root, 'data/chok-rambam');
const cyclesOut = opt('--cycles-out') || (apply ? cyclesIn : null);
const blocksOut = opt('--blocks-out') || (apply ? blocksDir : null);
const j = async u => { const r = await fetch(u); if (!r.ok) throw new Error(u + ' ' + r.status); return r.json(); };

const cyc = JSON.parse(readFileSync(cyclesIn, 'utf8'));
const R = cyc.rambam, BLK = cyc.block;
const oldOrder = R.order;

// 1. canonical books from Sefaria's TOC
const toc = await j('https://www.sefaria.org/api/index');
const find = n => Array.isArray(n) ? n.map(find).find(Boolean) : n && typeof n === 'object' ? (n.category === 'Mishneh Torah' ? n : (n.contents || []).map(find).find(Boolean)) : null;
const mt = find(toc);
const books = [];
(function walk(n, sef) { for (const c of n.contents) { if (c.contents) walk(c, c.category); else if (sef !== 'Introduction' && /^Mishneh Torah, /.test(c.title) && !books.includes(c.title)) books.push(c.title); } })(mt, '');
const chapters = {};
for (const b of books) { const ix = await j('https://www.sefaria.org/api/v2/raw/index/' + encodeURIComponent(b.replace(/ /g, '_')).replace(/%2C/g, ',')); chapters[b] = ix.schema.lengths[0]; }
const order = [];
for (const b of books) for (let ch = 1; ch <= chapters[b]; ch++) order.push({ ref: `${b} ${ch}`, book: b, ch });

// 2. sanity: same refs as before, only reordered
const oldRefs = new Set(oldOrder.map(e => e.ref));
if (order.length !== oldOrder.length || order.some(e => !oldRefs.has(e.ref))) throw new Error('ref set differs from current file - investigate before applying');
for (const b of books) if (!R.heNames[b] || !R.sefarim[b]) throw new Error('missing heNames/sefarim for ' + b);

// 3. official-cycle parameters (see check-rambam-cycle.mjs for the formula and its proof against Sefaria)
const n = order.length;
const skipIdx = order.findIndex(e => e.ref === 'Mishneh Torah, The Order of Prayer 5');
const next = { ...R, order, cycle: { start: '2026-02-03', intro1: 12, intro3: 4, skip1: [skipIdx], long3: 51 } };
// legacy single-anchor fields (still used by the old formula until index.html adopts `cycle`): today's official reading
const i1 = order.findIndex(e => e.ref === 'Mishneh Torah, Forbidden Intercourse 17');
const i3 = order.findIndex(e => e.ref === 'Mishneh Torah, Ownerless Property and Gifts 10');
next.anchorDate = '2026-11-05'; next.anchorIndex = i1; next.anchorIndex3 = i3;
console.log('books', books.length, 'chapters', n, 'first', order[0].ref, 'last', order[n - 1].ref, 'skip1 idx', skipIdx, 'anchors', i1, i3);

// 4. re-key blocks (every language variant)
const files = readdirSync(blocksDir).filter(f => /^\d+(\.[a-z]{2})?\.json$/.test(f));
const variants = [...new Set(files.map(f => f.replace(/^\d+/, '')))];
const outBlocks = {};
for (const v of variants) {
  const byRef = {};
  for (const f of files.filter(f => f.replace(/^\d+/, '') === v)) Object.assign(byRef, JSON.parse(readFileSync(join(blocksDir, f), 'utf8')));
  for (let b = 0; b * BLK < n; b++) {
    const o = {};
    for (const e of order.slice(b * BLK, (b + 1) * BLK)) { if (!(e.ref in byRef)) throw new Error(`missing ${e.ref} in ${v}`); o[e.ref] = byRef[e.ref]; }
    outBlocks[b + v] = o;
  }
}
console.log('block files', Object.keys(outBlocks).length);
if (!cyclesOut && !blocksOut) { console.log('dry run OK - nothing written (use --apply)'); process.exit(0); }
const atomic = (p, s) => { writeFileSync(p + '.tmp', s); renameSync(p + '.tmp', p); };
if (blocksOut) { mkdirSync(blocksOut, { recursive: true }); for (const [f, o] of Object.entries(outBlocks)) atomic(join(blocksOut, f), JSON.stringify(o)); }
if (cyclesOut) atomic(cyclesOut, JSON.stringify({ ...cyc, rambam: next }));
console.log('written');
