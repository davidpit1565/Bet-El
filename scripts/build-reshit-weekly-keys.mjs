// The weekly Chok LeYisrael bundles (data/chok-leyisrael/<Parasha>[.lang].json) carry the Reshit Chokhmah excerpts of the week under
// keys like "Reshit Chokhmah, Gate of Fear 1:1-12" (or across chapters "...Gate of Love 6:38-7:5"). The value of such a key is the
// concatenation, in book order, of the paragraph arrays of every entry data/chok-reshit/<N>[.lang].json from the first to the last
// referenced entry. This script (re)builds those values for a language from its chok-reshit files and checks the rule against the
// Hebrew bundle. usage: node scripts/build-reshit-weekly-keys.mjs <lang|he> [--write]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const lang = process.argv[2] || 'he', WRITE = process.argv.includes('--write');
const suffix = lang === 'he' ? '' : '.' + lang;
const order = [];                       // [key, paragraphs] in book order
for (let n = 0; n <= 100; n++) {
  const f = path.join(ROOT, 'data/chok-reshit', n + suffix + '.json');
  if (!fs.existsSync(f)) { console.error('missing', f); process.exit(1); }
  for (const [k, v] of Object.entries(JSON.parse(fs.readFileSync(f, 'utf8')))) order.push([k, v]);
}
const idx = new Map(order.map(([k], i) => [k, i]));
const gate = (k) => /^(Reshit Chokhmah, Gate of [^\d]+?) (\d+):(\d+)(?:-(?:(\d+):)?(\d+))?$/.exec(k);
function valueFor(key) {
  const m = gate(key); if (!m) return null;
  const [, head, c1, a, c2, b] = m;
  const first = `${head} ${c1}:${a}`, last = b ? `${head} ${c2 || c1}:${b}` : first;
  const i = idx.get(first), j = idx.get(last);
  if (i == null || j == null || j < i) return null;
  return order.slice(i, j + 1).flatMap(([, v]) => v);
}
const dir = path.join(ROOT, 'data/chok-leyisrael');
let files = 0, keys = 0, bad = 0;
for (const f of fs.readdirSync(dir)) {
  const base = /^([A-Za-z-]+)\.json$/.exec(f); if (!base) continue;       // Hebrew bundle drives the key set
  const heB = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
  const rk = Object.keys(heB).filter((k) => k.startsWith('Reshit Chokhmah, Gate of '));
  if (!rk.length) continue;
  if (lang === 'he') {                                                     // verify the rule against the real Hebrew bundle
    for (const k of rk) { keys++; const v = valueFor(k); if (!v || JSON.stringify(v) !== JSON.stringify(heB[k])) { bad++; if (bad < 6) console.log('RULE MISMATCH', f, k); } }
    continue;
  }
  const tf = path.join(dir, `${base[1]}.${lang}.json`); if (!fs.existsSync(tf)) { console.error('missing bundle', tf); bad++; continue; }
  const tgt = JSON.parse(fs.readFileSync(tf, 'utf8'));
  let changed = 0;
  for (const k of rk) {
    const v = valueFor(k); keys++;
    if (!v) { bad++; console.log('cannot build', f, k); continue; }
    if (JSON.stringify(tgt[k]) !== JSON.stringify(v)) { tgt[k] = v; changed++; }
  }
  files++;
  if (changed && WRITE) fs.writeFileSync(tf, JSON.stringify(tgt));
}
console.log(`lang ${lang}: bundles ${files}, keys ${keys}, problems ${bad}`);
