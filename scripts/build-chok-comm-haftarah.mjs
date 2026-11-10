#!/usr/bin/env node
// Adds the commentary (Rashi / Targum / Metzudot) for HAFTARAH verses that no Nach day of the same week reads, so the
// bundle's _comm lacks them (Shemot+Matot Jeremiah 1, Beshalach Judges 5, Mishpatim Jer 33:25, Tzav Jer 9:22-23, Masei Jer 4:1-2).
// Reuses scripts/chok-comm-lib.mjs (Sefaria fetch, writers) and chok-comm-translit.mjs exactly as build-chok-comm.mjs does;
// it only ever ADDS, never touches an existing entry.   node scripts/build-chok-comm-haftarah.mjs [--write]
import fs from 'node:fs';
import * as L from './chok-comm-lib.mjs';
const WRITE = process.argv.includes('--write');
const FILES = ['Shemot', 'Matot', 'Beshalach', 'Mishpatim', 'Tzav', 'Masei'];

const todo = [];
for (const { name, file } of L.parashaList()) {
  if (!FILES.includes(file)) continue;
  const cm = L.loadBundle(file)._comm || {};
  const ids = new Set();
  for (const d of Object.values(L.INDEX.schedule[name] || {})) for (const r of d.haftarah || []) {
    const p = L.parseRef(r); if (!p || !L.CH_LEN[p.book]) continue;
    for (const [c, v] of L.expandRef(p)) ids.add(`${p.book} ${c}:${v}`);
  }
  for (const d of Object.values(L.INDEX.schedule[name] || {})) for (const s of d.haftarah_seph || []) {   // Sephardi segments {k,b,e}
    const p = L.parseRef(`${s.k} ${s.b}-${s.e}`); if (!p || !L.CH_LEN[p.book]) continue;
    for (const [c, v] of L.expandRef(p)) ids.add(`${p.book} ${c}:${v}`);
  }
  for (const id of ids) {
    const book = id.replace(/ \d+:\d+$/, ''); const [c, v] = id.split(' ').pop().split(':').map(Number);
    for (const w of L.sourcesFor(book)) if (!(cm[id] && cm[id][w])) todo.push({ file, id, w, book, c, v });
  }
}
console.log(todo.length, "(verse, source) pairs missing", JSON.stringify(todo.reduce((a,t)=>{const k=t.file+" "+t.id.replace(/:\d+$/,"");a[k]=(a[k]||0)+1;return a},{})));
const add = new Map(), none = [];
const cleanNew = (p) => p.replace(/<(\/?)([a-zA-Z]+)[^>]*>/g, (a, sl, t) => (t.toLowerCase() === 'b' ? `<${sl}b>` : ' ')).replace(/\s{2,}/g, ' ').replace(/\s+([.,:;])/g, '$1').trim();
for (const t of todo) {
  let got = (await L.sefariaChapter(t.w, t.book, t.c)).verses.get(t.v);
  if (!got && ['rashi', 'targum'].includes(t.w)) { const f = await L.sefariaVerse(t.w, t.book, t.c, t.v); if (f) got = f.paras; }
  const paras = (got || []).map(cleanNew).filter(Boolean);
  if (!paras.length) { none.push(`${t.file} ${t.id} ${t.w}`); continue; }
  if (!add.has(t.file)) add.set(t.file, new Map());
  const m = add.get(t.file); if (!m.has(t.id)) m.set(t.id, {});
  m.get(t.id)[t.w] = paras;
}
console.log('added pairs', [...add.values()].reduce((a, m) => a + [...m.values()].reduce((x, o) => x + Object.keys(o).length, 0), 0));
console.log('Sefaria has none for', none.length); none.forEach((x) => console.log('  ', x));
if (!WRITE) process.exit(0);

const { trCommentary } = await import('./chok-comm-translit.mjs');
const TR = new Set(['rashi', 'targum', 'ohc']);
const rank = (k) => { const i = L.SRC_ORDER.indexOf(k); return i < 0 ? -1 : i; };
const changed = [];
for (const [file, m] of add) for (const lang of ['he', ...L.LANGS]) {
  const { obj, style } = L.readBundleRaw(file, lang === 'he' ? undefined : lang);
  obj._comm = obj._comm || {};
  for (const [id, a] of m) {
    const cur = obj._comm[id] || {}; const nu = { ...cur };
    for (const [w, paras] of Object.entries(a)) {
      if (w in cur) continue;
      if (lang !== 'he' && !TR.has(w)) continue;
      nu[w] = lang === 'he' ? paras : paras.map((p) => trCommentary(lang, p));
    }
    const o = {}; Object.keys(nu).sort((x, y) => rank(x) - rank(y)).forEach((k) => { o[k] = nu[k]; });
    obj._comm[id] = o;
  }
  L.writeBundle(file, lang === 'he' ? undefined : lang, obj, style); changed.push(L.bundlePath(file, lang === 'he' ? undefined : lang));
}
fs.appendFileSync('/tmp/claude-0/-home-user/3151a7b9-ad24-54e8-aa44-c519d5e1d6d7/scratchpad/fixlog/haftarah-comm.txt', changed.join('\n') + '\n');
console.log('written', changed.length);
