#!/usr/bin/env node
/* Builds data/mishnah-translit/<slug>.<lang>.json (en/fr/ru/ka) for the Library Mishnah reader.
 * Source: data/chok-leyisrael/<parasha>.<lang>.json - same keys + same per-key array order as the
 * Hebrew file, whose _mrefs map gives the individual "Mishnah X a:b" / "Pirkei Avot a:b" refs.
 * Shape per file: { "<chapter>": { "<mishnah>": "<translit text>" } }. Re-run after chok-leyisrael changes. */
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
const LANGS = ['en', 'fr', 'ru', 'ka'];
const idx = JSON.parse(readFileSync('data/chok-leyisrael-index.json', 'utf8'));
const slug = en => en.replace(/[^A-Za-z0-9]+/g, '-').replace(/^-|-$/g, '');
function parseRef(ref) {
  let m = /^Mishnah (.+) (\d+):(\d+)$/.exec(ref);
  if (m) return { t: m[1], ch: +m[2], n: +m[3] };
  m = /^Pirkei Avot (\d+):(\d+)$/.exec(ref);
  return m ? { t: 'Avot', ch: +m[1], n: +m[2] } : null;
}
mkdirSync('data/mishnah-translit', { recursive: true });
let problems = 0;
for (const lang of LANGS) {
  const out = {};
  for (const key of idx.parshiot) {
    const he = JSON.parse(readFileSync(`data/chok-leyisrael/${slug(key)}.json`, 'utf8'));
    const tr = JSON.parse(readFileSync(`data/chok-leyisrael/${slug(key)}.${lang}.json`, 'utf8'));
    for (const k of Object.keys(he)) {
      if (!k.startsWith('Mishnah ') && !k.startsWith('Pirkei Avot ')) continue;
      const refs = (he._mrefs || {})[k] || [k];
      const a = tr[k];
      if (!Array.isArray(a) || a.length !== he[k].length) { console.error('MISMATCH', lang, key, k); problems++; continue; }
      a.forEach((txt, i) => {
        const p = parseRef(refs[i]);
        if (!p) { problems++; return; }
        const o = out[p.t] || (out[p.t] = {});
        const c = o[p.ch] || (o[p.ch] = {});
        if (c[p.n] === undefined) c[p.n] = txt.replace(/<i data-overlay="Vilna Pages"[^>]*><\/i>/g, '').trim();
      });
    }
  }
  for (const [t, o] of Object.entries(out)) writeFileSync(`data/mishnah-translit/${slug(t)}.${lang}.json`, JSON.stringify(o));
  console.log(lang, Object.keys(out).length, 'tractates');
}
console.log('problems', problems);
