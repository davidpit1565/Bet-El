// Output hygiene check for data/sa-harav/oc/*.ka.json: no iii, Latin, Hebrew, doubled consonants (listed). node scripts/translit/check-ka.mjs
import fs from 'node:fs';
const dir = 'data/sa-harav/oc';
const words = new Map();
for (const f of fs.readdirSync(dir).filter((f) => /^\d+\.ka\.json$/.test(f))) {
  const d = JSON.parse(fs.readFileSync(dir + '/' + f, 'utf8'));
  for (const s of [d.t, ...d.s]) {
    const clean = s.replace(/<\/?b>/g, '');
    for (const w of clean.split(/[\s\-—:;,.?!()\[\]"'…]+/)) if (w) words.set(w, (words.get(w) || 0) + 1);
  }
}
let tot = 0; const bad = { iii: [], latin: [], heb: [], dbl: new Map(), nongeo: new Map() };
for (const [w, c] of words) {
  tot += c;
  if (/იიი/.test(w)) bad.iii.push(w);
  if (/[A-Za-z]/.test(w)) bad.latin.push(w);
  if (/[֐-׿]/.test(w)) bad.heb.push(w);
  if (/([ბგდვზთკლმნპჟრსტფქღყშჩცძწჭხჯჰ])\1/.test(w)) bad.dbl.set(w, c);
  for (const ch of w) if (!/[ა-ჰ0-9]/.test(ch)) bad.nongeo.set(ch, (bad.nongeo.get(ch) || 0) + c);
}
console.log('tokens', tot, 'unique', words.size);
console.log('iii', bad.iii.length, bad.iii.slice(0, 10));
console.log('latin', bad.latin.length, bad.latin.slice(0, 20));
console.log('hebrew', bad.heb.length, bad.heb.slice(0, 20));
console.log('double consonant unique', bad.dbl.size, 'tokens', [...bad.dbl.values()].reduce((a, b) => a + b, 0));
const roots = new Map();
for (const [w, c] of bad.dbl) for (const x of w.match(/([ა-ჰ])\1/g)) roots.set(x, (roots.get(x) || 0) + c);
console.log([...roots]);
console.log([...bad.dbl].sort((a, b) => b[1] - a[1]).slice(0, 60).map((x) => x.join(':')).join(' '));
console.log('nongeo chars', [...bad.nongeo].slice(0, 30));
let vv = 0; for (const [w, c] of words) if (/(ეე|ოო|უუ)/.test(w)) vv += c; console.log('ee/oo/uu tokens', vv);
console.log([...words].filter(([w]) => /(ეე|ოო|უუ)/.test(w)).sort((a, b) => b[1] - a[1]).slice(0, 15).join(' | '));
