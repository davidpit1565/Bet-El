#!/usr/bin/env node
/* Download the French Torah text (Bible du Rabbinat 1899, Zadoc Kahn - public domain, via Sefaria's API)
   usage: node scripts/fr-booklet/fetch-french-torah.mjs [out.json]
   Output shape matches data/torah-data.json: { Genesis: [ chapter: [ verse: "text" ] ] } */
import fs from 'fs';
const out = process.argv[2] || new URL('./torah-rabbinat-fr.json', import.meta.url).pathname;
const BOOKS = ['Genesis','Exodus','Leviticus','Numbers','Deuteronomy'];
const VERSION = 'french|Bible du Rabbinat 1899 [fr]';
const res = {};
for (const b of BOOKS) {
  const u = `https://www.sefaria.org/api/v3/texts/${encodeURIComponent(b)}?version=${encodeURIComponent(VERSION)}`;
  let j;
  for (let t = 0; t < 4; t++) {
    try { const r = await fetch(u); if (!r.ok) throw new Error(r.status); j = await r.json(); break; }
    catch (e) { console.error(b, 'retry', e.message); await new Promise(r => setTimeout(r, 2000 << t)); }
  }
  const v = j.versions.find(x => /Rabbinat/.test(x.versionTitle));
  res[b] = v.text;
  console.error(b, v.text.length, 'chapters', v.text.reduce((n, c) => n + c.length, 0), 'verses');
}
fs.writeFileSync(out, JSON.stringify(res));
