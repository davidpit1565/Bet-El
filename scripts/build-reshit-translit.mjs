// Phonetic transliteration (NOT translation) of Reshit Chokhmah into fr / ru, as the owner asked (2026-11-07): the Hebrew in
// data/chok-reshit/<N>.json has no nikud, so it is first vocalized with Dicta Nakdan (scripts/vocalize-reshit.mjs, cached per
// file) and then run through the same rule-based engine + conventions as the Rashi/Targum transliteration in the weekly bundles
// (trCommentary in scripts/chok-comm-translit.mjs). Writes data/chok-reshit/<N>.<lang>.json (same keys / array lengths / tag order).
// usage: node scripts/build-reshit-translit.mjs <vocDir> [--langs fr,ru] [--from N --to M] [--dry]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { trCommentary } from './chok-comm-translit.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const VOC = args[0];
const opt = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
const LANGS = opt('--langs', 'fr,ru').split(',');
const FROM = +opt('--from', 0), TO = +opt('--to', 100), DRY = args.includes('--dry');
// Dicta vocalizes the Hebrew-letter numerals of citations ((שם יא, יט) -> יָא) which the citation-numeral pass of trCommentary then
// skips (it only converts bare letters); strip the nikud of 1-3 letter gematria tokens inside parentheses so they become digits
// like in the Rashi/Targum citations of the weekly bundles.
const GV = { א: 1, ב: 2, ג: 3, ד: 4, ה: 5, ו: 6, ז: 7, ח: 8, ט: 9, י: 10, כ: 20, ך: 20, ל: 30, מ: 40, ם: 40, נ: 50, ן: 50, ס: 60, ע: 70, פ: 80, ף: 80, צ: 90, ץ: 90, ק: 100, ר: 200, ש: 300, ת: 400 };
const isGem = (w) => { let prev = 1e9; for (const ch of w) { const v = GV[ch]; if (!v || v > prev || (v === prev && v < 100)) return false; prev = v; } return true; };
const fixCit = (p) => p.replace(/\(([^()]*)\)/g, (all, inner) => '(' + inner.split(/(\s+)/).map((tok) => {
  const b = tok.replace(/[\u0591-\u05C7]/g, '');
  const m = /^([א-ת]{1,3})([.,;:]*)$/.exec(b);
  return m && isGem(m[1]) && b !== tok && !/^[אהו]$/.test(m[1]) ? b : tok;
}).join('') + ')');
const tags = (s) => (s.match(/<[^>]*>/g) || []).join('');
const problems = [];
let paras = 0, noVowel = 0;
for (let n = FROM; n <= TO; n++) {
  const heF = path.join(ROOT, 'data/chok-reshit', n + '.json');
  const vocF = path.join(VOC, n + '.json');
  if (!fs.existsSync(vocF)) { problems.push(`${n}: missing vocalized file`); continue; }
  const he = JSON.parse(fs.readFileSync(heF, 'utf8')), voc = JSON.parse(fs.readFileSync(vocF, 'utf8'));
  for (const lang of LANGS) {
    const out = {};
    for (const [k, arr] of Object.entries(he)) {
      out[k] = arr.map((p, i) => {
        const v = (voc[k] || [])[i];
        if (v == null) { problems.push(`${n}/${k}[${i}]: no vocalized paragraph`); return p; }
        const t = trCommentary(lang, fixCit(v)).normalize('NFC');
        paras++;
        if (tags(t) !== tags(p)) problems.push(`${n}/${k}[${i}] ${lang}: tag sequence differs`);
        if (/[א-ת]/.test(t.replace(/<[^>]*>/g, ''))) problems.push(`${n}/${k}[${i}] ${lang}: Hebrew letters left`);
        if (lang === 'ru' && /[A-Za-z]/.test(t.replace(/<[^>]*>/g, '').replace(/&\w+;/g, ''))) problems.push(`${n}/${k}[${i}] ru: Latin letters left`);
        return t;
      });
    }
    if (Object.keys(out).join('|') !== Object.keys(he).join('|')) problems.push(`${n} ${lang}: keys differ`);
    if (!DRY) fs.writeFileSync(path.join(ROOT, 'data/chok-reshit', `${n}.${lang}.json`), JSON.stringify(out));
  }
}
console.log(`paragraphs ${paras}, problems ${problems.length}`);
problems.slice(0, 40).forEach((x) => console.log(' ', x));
