// Removes editorial variant-reading marks (נ"י, ס"א, גי' רמב"ן, עי' רש"י, לפרש"י, בנ"י איננו) from the Targum
// (element [1]) of data/torah-data.json and the aligned token in each torah-<lang>.json translit.
// Alignment is by whitespace token index; a verse is skipped (and reported) if token counts differ.
import fs from 'fs';
const dir = new URL('../data/', import.meta.url).pathname;
const langs = ['en','fr','ru','ka'];
const he = JSON.parse(fs.readFileSync(dir+'torah-data.json','utf8'));
const tr = Object.fromEntries(langs.map(l=>[l, JSON.parse(fs.readFileSync(dir+`torah-${l}.json`,'utf8'))]));
// a token (or token run) to drop, matched on the Hebrew side
const runs = [['בנ"י','איננו'],['גי\'','רמב"ן'],['עי\'','רש"י'],['נ"י'],['ס"א'],['לפרש"י']];
const log = [];
let changed = 0, skipped = 0;
for (const bk of Object.keys(he)) he[bk].forEach((ch,ci)=>ch.forEach((v,vi)=>{
  const t = v[1];
  if (!/["']/.test(t)) return;
  const w = t.split(/\s+/);
  const drop = new Set();
  for (let i=0;i<w.length;i++) for (const r of runs) {
    if (r.every((x,k)=>w[i+k]===x)) { r.forEach((_,k)=>drop.add(i+k)); i+=r.length-1; break; }
  }
  if (!drop.size) { log.push(`UNHANDLED ${bk} ${ci+1}:${vi+1} ${t}`); return; }
  const out = {};
  let ok = true;
  for (const l of langs) {
    const x = tr[l][bk][ci][vi][1].split(/\s+/);
    if (x.length !== w.length) { ok = false; break; }
    out[l] = x.filter((_,i)=>!drop.has(i)).join(' ');
  }
  if (!ok) { skipped++; log.push(`SKIPPED (token mismatch) ${bk} ${ci+1}:${vi+1}`); return; }
  const after = w.filter((_,i)=>!drop.has(i)).join(' ');
  log.push(`${bk} ${ci+1}:${vi+1}\n  he before: ${t}\n  he after:  ${after}`);
  for (const l of langs) { log.push(`  ${l} before: ${tr[l][bk][ci][vi][1]}\n  ${l} after:  ${out[l]}`); tr[l][bk][ci][vi][1] = out[l]; }
  v[1] = after; changed++;
}));
const indent = s => s; 
fs.writeFileSync(dir+'torah-data.json', JSON.stringify(he));
for (const l of langs) fs.writeFileSync(dir+`torah-${l}.json`, JSON.stringify(tr[l]));
fs.writeFileSync(process.argv[2], log.join('\n')+`\n\nchanged verses: ${changed}, skipped: ${skipped}\n`);
console.log('changed',changed,'skipped',skipped);
