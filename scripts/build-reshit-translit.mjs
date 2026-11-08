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

// Abbreviations / letter-names / bare numerals that Dicta leaves without nikud are given their spoken form (vocalized Hebrew) before
// the engine runs - otherwise they come out as consonant strings ("hkbh", "yDvD"). Only the sound of the spoken form is copied.
const SPOKEN = {
  'ע"א': 'עַמּוּד אָלֶף', 'ע"ב': 'עַמּוּד בֵּית', 'ע"ה': 'עָלָיו הַשָּׁלוֹם', 'עכ"ל': 'עַד כָּאן לְשׁוֹנוֹ', 'הקב"ה': 'הַקָּדוֹשׁ בָּרוּךְ הוּא',
  'קוב"ה': 'קוּדְשָׁא בְּרִיךְ הוּא', 'שה"ש': 'שִׁיר הַשִּׁירִים', 'כמ"ש': 'כְּמוֹ שֶׁכָּתוּב', 'הה"ד': 'הֲדָא הוּא דִכְתִיב', 'ח"ו': 'חַס וְשָׁלוֹם',
  'שמ"א': 'שְׁמוּאֵל א׳', 'שמ"ב': 'שְׁמוּאֵל ב׳', 'מל"א': 'מְלָכִים א׳', 'מל"ב': 'מְלָכִים ב׳', 'דה"א': 'דִּבְרֵי הַיָּמִים א׳', 'דה"ב': 'דִּבְרֵי הַיָּמִים ב׳',
  'ת"ז': 'תִּקּוּנֵי זֹהַר', 'ת"ח': 'תַּלְמִיד חָכָם', 'ז"ל': 'זִכְרוֹנוֹ לִבְרָכָה', 'ב"ה': 'בָּרוּךְ הוּא', 'ר"ל': 'רַחֲמָנָא לִצְלַן',
  'ידו"ד': 'יְהֹוָה', 'בידו"ד': 'בַּיהֹוָה', 'לידו"ד': 'לַיהֹוָה', 'אדנ"י': 'אֲדֹנָי', 'סמא"ל': 'סַמָּאֵל', 'מטטרו"ן': 'מְטַטְרוֹן',
  'י"ה': 'יוֹד הֵא', 'ו"ה': 'וָו הֵא', 'מ"ה': 'מֵם הֵא', 'מ"י': 'מֵם יוֹד', 'ק"א': 'קוֹף אָלֶף',
};
const PREFIX = { ד: 'דְּ', ל: 'לְ', ב: 'בְּ', ו: 'וְ', ה: 'הַ', כ: 'כְּ', ש: 'שֶׁ', מ: 'מֵ' };
const SPOKEN_N = new Map(Object.entries(SPOKEN));
const GVN = { א: 1, ב: 2, ג: 3, ד: 4, ה: 5, ו: 6, ז: 7, ח: 8, ט: 9, י: 10, כ: 20, ך: 20, ל: 30, מ: 40, ם: 40, נ: 50, ן: 50, ס: 60, ע: 70, פ: 80, ף: 80, צ: 90, ץ: 90, ק: 100, ר: 200, ש: 300, ת: 400 };
function gemNum(w) { let prev = 1e9, sum = 0; for (const ch of w) { const v = GVN[ch]; if (!v || v > prev || (v === prev && v < 100)) return null; prev = v; sum += v; } return sum; }
const expandAbbrev = (p) => p.split(/(<[^>]*>)/).map((x) => /^<[^>]*>$/.test(x) ? x : x.replace(/(^|[^א-תְ-ׇ'"׳״])([א-ת]{1,6}["״׳']?[א-ת]{0,3})(?![א-תְ-ׇ])/g, (all, pre, w) => {
  if (SPOKEN_N.has(w)) return pre + SPOKEN_N.get(w);
  if (PREFIX[w[0]] && SPOKEN_N.has(w.slice(1))) return pre + PREFIX[w[0]] + SPOKEN_N.get(w.slice(1));
  const bare = w.replace(/["״׳']/g, '');
  if (bare.length >= 2 && bare.length <= 3 && /^[א-ת]+$/.test(bare)) { const n = gemNum(bare); if (n && n < 1000 && w.replace(/["״]/g, '').length === bare.length) return pre + n; }
  return all;
})).join('');
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
        const t = trCommentary(lang, fixCit(expandAbbrev(v))).normalize('NFC');
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
