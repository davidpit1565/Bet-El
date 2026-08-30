#!/usr/bin/env node
/* Builds data/mishnah-index.json - a DERIVED index, not new source content.
 * Every mishnah text here is already shipped in data/chok-leyisrael/*.json
 * (under keys like "Mishnah Berakhot 1:1-4" with parallel _mrefs/_labels
 * maps). This script just walks all 54 parasha files once, explodes those
 * ranges back into individual mishnayot, and groups them into the
 * standard seder -> tractate -> chapter -> mishnah hierarchy for the
 * Library's free-browsing Mishnah screens. Re-run this whenever the
 * chok-leyisrael data changes.
 */
import { readFileSync, writeFileSync, readdirSync } from 'fs';

const SEDARIM = {
  'Zeraim': ['Berakhot','Peah','Demai','Kilayim','Sheviit','Terumot','Maasrot','Maaser Sheni','Challah','Orlah','Bikkurim'],
  'Moed': ['Shabbat','Eruvin','Pesachim','Shekalim','Yoma','Sukkah','Beitzah','Rosh Hashanah',"Ta'anit",'Megillah','Moed Katan','Chagigah'],
  'Nashim': ['Yevamot','Ketubot','Nedarim','Nazir','Sotah','Gittin','Kiddushin'],
  'Nezikin': ['Bava Kamma','Bava Metzia','Bava Batra','Sanhedrin','Makkot','Shevuot','Eduyot','Avodah Zarah','Avot','Horayot'],
  'Kodashim': ['Zevachim','Menachot','Chullin','Bekhorot','Arakhin','Temurah','Keritot','Meilah','Tamid','Middot','Kinnim'],
  'Taharot': ['Kelim','Oholot','Negaim','Parah','Tahorot','Mikvaot','Niddah','Makhshirin','Zavim','Tevul Yom','Yadayim','Oktzin'],
};
const TRACTATE_SEDER = {};
for (const [seder, list] of Object.entries(SEDARIM)) for (const t of list) TRACTATE_SEDER[t] = seder;

const idx = JSON.parse(readFileSync('data/chok-leyisrael-index.json', 'utf8'));
const parshiot = idx.parshiot;

// masechet -> chapter(number) -> mishnah(number) -> {label, text}
const data = {};
let totalMishnayot = 0, skippedNoRef = 0;

function parseRef(ref) {
  // "Mishnah Berakhot 1:1" or "Mishnah Bava Batra 2:3" (tractate names can have spaces)
  const m = /^Mishnah (.+) (\d+):(\d+)$/.exec(ref);
  if (!m) return null;
  return { masechet: m[1], ch: +m[2], n: +m[3] };
}

function chokSlug(en) { return en.replace(/[^A-Za-z0-9]+/g, '-').replace(/^-|-$/g, ''); }

for (const key of parshiot) {
  const file = `data/chok-leyisrael/${chokSlug(key)}.json`;
  let d;
  try { d = JSON.parse(readFileSync(file, 'utf8')); }
  catch (e) { console.error('MISSING/BAD FILE', file, e.message); continue; }
  const mrefs = d._mrefs || {};
  const labels = d._labels || {};
  for (const k of Object.keys(d)) {
    if (!k.startsWith('Mishnah ')) continue;
    const texts = d[k];
    const refs = mrefs[k] || [k];
    const labs = labels[k] || refs.map(() => null);
    if (!Array.isArray(texts)) continue;
    for (let i = 0; i < texts.length; i++) {
      const ref = refs[i];
      const parsed = ref && parseRef(ref);
      if (!parsed) { skippedNoRef++; continue; }
      const { masechet, ch, n } = parsed;
      if (!data[masechet]) data[masechet] = {};
      if (!data[masechet][ch]) data[masechet][ch] = {};
      if (data[masechet][ch][n]) continue; // already collected (weeks don't overlap, but be safe)
      data[masechet][ch][n] = { label: labs[i] || null, text: texts[i] };
      totalMishnayot++;
    }
  }
}

// Build the ordered structure the app will consume.
const out = { sedarim: [] };
for (const seder of Object.keys(SEDARIM)) {
  const tractates = [];
  for (const masechet of SEDARIM[seder]) {
    const chNums = Object.keys(data[masechet] || {}).map(Number).sort((a, b) => a - b);
    if (!chNums.length) continue; // not present in the shipped daily-cycle data - skip (e.g. Avot, or a tractate this cycle doesn't cover)
    const chapters = chNums.map(ch => {
      const mNums = Object.keys(data[masechet][ch]).map(Number).sort((a, b) => a - b);
      return {
        ch,
        mishnayot: mNums.map(n => {
          const e = data[masechet][ch][n];
          return { n, label: e.label, text: e.text };
        }),
      };
    });
    tractates.push({ masechet, chapters });
  }
  if (tractates.length) out.sedarim.push({ seder, tractates });
}

writeFileSync('data/mishnah-index.json', JSON.stringify(out));
console.log('Total mishnayot collected:', totalMishnayot, 'skipped (no parsable ref):', skippedNoRef);
console.log('Sedarim with content:', out.sedarim.map(s => s.seder + '(' + s.tractates.length + ' tractates)').join(', '));
for (const s of out.sedarim) for (const t of s.tractates) {
  const nCh = t.chapters.length;
  console.log('  ', s.seder, '/', t.masechet, ':', nCh, 'chapters');
}
