// Vocalizes the (unvocalized) Reshit Chokhmah Hebrew with the Dicta Nakdan API (the same service the rest of the app's
// vocalized text came from) and caches the result per file: <outDir>/<N>.json has the same shape as data/chok-reshit/<N>.json
// (key -> [paragraph with tags]) but with nikud on every Hebrew word. Only text nodes are sent; HTML tags stay untouched.
// usage: node scripts/vocalize-reshit.mjs <outDir> [fromN toN]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = process.argv[2];
const FROM = +(process.argv[3] ?? 0), TO = +(process.argv[4] ?? 100);
if (!OUT) { console.error('usage: vocalize-reshit.mjs <outDir> [from to]'); process.exit(1); }
fs.mkdirSync(OUT, { recursive: true });
const URLS = ['https://nakdan-u1-0.loadbalancer.dicta.org.il/api'];
const SEP = '‡';
const stripNikud = (s) => s.replace(/[֑-ׇ|]/g, '');
// Dicta normalises Hebrew spelling (e.g. שואל -> שֹׁאֵל), so the vocalized text is NOT letter-identical to the source: only the
// sound matters here (the Hebrew itself is never shown for fr/ru). Sanity check = similar count of Hebrew letters.
const hebCount = (s) => (s.match(/[א-ת]/g) || []).length;
const sane = (t, u) => { const a = hebCount(t), b = hebCount(u); return b === 0 ? a === 0 : Math.abs(a - b) <= Math.max(2, b * 0.15); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function nakdan(text, tries = 6) {
  for (let a = 0; a < tries; a++) {
    try {
      const r = await fetch(URLS[0], { method: 'POST', headers: { 'Content-Type': 'application/json' }, signal: AbortSignal.timeout(90000),
        body: JSON.stringify({ task: 'nakdan', genre: 'modern', data: text, addmorph: false, matchpartial: true, keepmetagim: false, keepqq: false, nodageshmem: false, patachma: false, useTokenization: false }) });
      if (r.status !== 200) throw new Error('HTTP ' + r.status);
      const j = await r.json();
      if (!Array.isArray(j)) throw new Error('bad payload');
      return j.map((x) => (x.sep ? x.word : (x.options && x.options.length ? x.options[0] : x.word)).replace(/\|/g, '')).join('');
    } catch (e) { if (a === tries - 1) throw e; await sleep(1500 * (a + 1)); }
  }
}

// split a paragraph into [tag|text] pieces
const pieces = (p) => p.split(/(<[^>]*>)/).filter((x) => x !== '');
const isTag = (x) => /^<[^>]*>$/.test(x);

async function vocalizeUnits(units) {
  // units: array of text strings (each with Hebrew); returns vocalized array; chunked, aligned by SEP markers
  const res = new Array(units.length);
  let i = 0;
  while (i < units.length) {
    let j = i, len = 0;
    while (j < units.length && (j === i || len + units[j].length < 5500)) { len += units[j].length + 1; j++; }
    const chunk = units.slice(i, j);
    let out = null;
    try {
      const txt = (await nakdan(chunk.join(SEP))).split(SEP);
      if (txt.length === chunk.length && txt.every((t, k) => sane(t, chunk[k]))) out = txt;
    } catch (e) { /* fall through to per-unit */ }
    if (!out) {
      out = [];
      for (const u of chunk) {
        try { const t = await nakdan(u); out.push(sane(t, u) ? t : u); }
        catch (e) { out.push(u); console.error('FALLBACK unvocalized unit', u.slice(0, 40)); }
      }
    }
    for (let k = 0; k < chunk.length; k++) res[i + k] = out[k];
    i = j;
  }
  return res;
}

for (let n = FROM; n <= TO; n++) {
  const outF = path.join(OUT, n + '.json');
  if (fs.existsSync(outF)) continue;
  const src = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/chok-reshit', n + '.json'), 'utf8'));
  const units = [], where = [];
  for (const [k, arr] of Object.entries(src)) arr.forEach((p, pi) => pieces(p).forEach((x, xi) => { if (!isTag(x) && /[א-ת]/.test(x)) { units.push(x); where.push([k, pi, xi]); } }));
  if (units.some((u) => u.includes(SEP))) throw new Error('separator char present in source ' + n);
  const voc = await vocalizeUnits(units);
  const outObj = {};
  for (const [k, arr] of Object.entries(src)) outObj[k] = arr.map((p) => pieces(p));
  where.forEach(([k, pi, xi], idx) => { outObj[k][pi][xi] = voc[idx]; });
  for (const k of Object.keys(outObj)) outObj[k] = outObj[k].map((ps) => ps.join(''));
  fs.writeFileSync(outF, JSON.stringify(outObj));
  console.log('vocalized', n, units.length, 'units');
}
