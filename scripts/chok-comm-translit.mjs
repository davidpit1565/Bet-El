// Phonetic transliteration of the Chok LeYisrael commentary (Rashi / Targum / Or HaChaim) into en / fr / ru / ka,
// in the convention the EXISTING variant bundles (data/chok-leyisrael/<Parasha>.<lang>.json) already use, so a
// newly added entry reads like its neighbours. It runs the repo's rule-based engine (scripts/translit/) and then
// applies the conventions that engine's defaults do not share with the existing text:
//   * only the first letter of a paragraph is capitalised (plus divine names); "Hashem" is written Adonai (en/ka)
//   * the quote mark of an abbreviation is dropped (ta"l -> tal), real quotations keep theirs
//   * Hebrew-letter numerals in citations become digits (טז:ב -> 16:2, שמואל ב -> Shmuel 2)
//   * unvocalized words (book / midrash names, וגו', ...) come from scripts/chok-comm-lexicon.json, which is MINED from
//     the existing variant entries (word-aligned with their Hebrew, >=3 observations, >=60% agreement)
//   * Georgian: the engine's "recommended" scheme differs from the app's data (which doubles letters, writes ი+ი, uses
//     კ/წ/პ); the per-language adaptation below follows the existing data instead
import fs from 'node:fs';
import path from 'node:path';
import { ROOT } from './chok-comm-lib.mjs';

const T = path.join(ROOT, 'scripts/translit');
const { transliterate, newStats } = await import(path.join(T, 'core.mjs'));
const mods = {};
for (const l of ['en', 'fr', 'ru', 'ka']) mods[l] = await import(path.join(T, `${l}.mjs`));

const LEGACY_EN = { bSoft: 'v', kafSoft: 'ch', finalKafNach: 'ch', pSoft: 'f', qof: 'k', qamatzYodVav: 'av', shinGem: 'sh',
  finalHeAfter: { a: '', e: '', o: '', i: '', u: '', patach: '' }, capitalizeParagraph: false, divine: { tetragrammaton: 'Adonai', hashem: 'Adonai' } };

function kaScheme() {
  const base = mods.ka.createScheme({ divine: { tetragrammaton: 'ადონაი', hashem: 'ადონაი' }, maxI: 3 });
  const consonant = base.consonant.bind(base);
  base.consonant = (p, ph, i) => {
    if (p.mater && p.id === 'yod') return '';
    if (p.id === 'ayin') return '';                       // the existing text writes no letter for ayin
    if (p.id === 'tsadi') return 'წ';
    if (p.id === 'pe') return p.soft ? 'ფ' : 'პ';         // pe rafe / pe dagesh
    if (p.id === 'kaf') return p.soft ? 'ხ' : 'კ';
    return consonant(p, ph, i);
  };
  base.geminate = (s) => s + s;                           // the existing text doubles dagesh chazak
  base.post = (parts) => {                                // the engine's post step minus its yod+hirik collapse (existing: ისრაელ -> იისრაელ)
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      if (!(part.p && part.p.k === 'C' && part.p.vowelless && !part.p.unvoc && part.s)) continue;
      if (part.p.id === 'vav' && i === 0) {
        const nx = parts.slice(1).find((q) => q.p && q.p.k === 'C');
        part.s = nx && ['bet', 'mem', 'pe'].includes(nx.p.id) ? 'უ' : 'ვე';
      } else part.s += 'ა';
    }
    for (let i = 0; i < parts.length; i++) {              // qamatz + yod + final vav (ָיו) is read av: drop the yod
      const p = parts[i].p;
      if (p && p.k === 'C' && p.glide) {
        const nx = parts[i + 1] && parts[i + 1].p;
        if (p.afterSrc === 'qamatz' && nx && nx.k === 'C' && nx.id === 'vav' && i + 2 === parts.length) parts[i].s = '';
      }
    }
  };
  return base;
}
const SCHEMES = { en: mods.en.createScheme(LEGACY_EN), fr: mods.fr.scheme, ru: mods.ru.scheme, ka: kaScheme() };

// ---- gematria numerals in citations ----
const GV = { א: 1, ב: 2, ג: 3, ד: 4, ה: 5, ו: 6, ז: 7, ח: 8, ט: 9, י: 10, כ: 20, ך: 20, ל: 30, מ: 40, ם: 40, נ: 50, ן: 50, ס: 60, ע: 70, פ: 80, ף: 80, צ: 90, ץ: 90, ק: 100, ר: 200, ש: 300, ת: 400 };
function gem(tok) {
  const s = tok.replace(/[׳״'"]/g, '');
  if (!/^[א-ת]{1,3}$/.test(s)) return null;
  let prev = 1e9, sum = 0;
  for (const ch of s) { const v = GV[ch]; if (v > prev) return null; if (v === prev && v < 100) return null; prev = v; sum += v; }
  return sum;
}
const NUM_AFTER = new Set(['פרשה', 'פרק', 'סימן', 'דף', 'פסוק', 'הלכה', 'מצוה', 'סעיף', 'אות', 'שער', 'פרקים', 'עמוד']);
export function numerals(text) {
  // protect tags
  return text.replace(/\(([^()]*)\)/g, (all, inner) => {
    const toks = inner.split(/(\s+)/);
    for (let i = 0; i < toks.length; i++) {
      const t = toks[i]; if (!t || /^\s+$/.test(t)) continue;
      if (/[֑-ׇ]/.test(t)) continue;
      const m = /^([א-ת׳״'"]{1,5}):([א-ת׳״'"]{1,5})([.,;:]*)$/.exec(t);
      if (m) { const a = gem(m[1]), b = gem(m[2]); if (a && b) toks[i] = `${a}:${b}${m[3]}`; continue; }
      const m2 = /^([א-ת׳״'"]{1,4})([.,;:]*)$/.exec(t);
      if (m2) {
        const prevWord = toks.slice(0, i).reverse().find((x) => x && !/^\s+$/.test(x));
        if (!prevWord) continue;
        const single = m2[1].replace(/[׳״'"]/g, '').length === 1;
        if (single || NUM_AFTER.has(prevWord.replace(/[.,;:]+$/, ''))) { const n = gem(m2[1]); if (n) toks[i] = n + m2[2]; }
      }
    }
    return '(' + toks.join('') + ')';
  });
}

// ---- lexicon of unvocalized words, mined from the existing variants ----
const LEX_PATH = path.join(ROOT, 'scripts/chok-comm-lexicon.json');
let LEX = null;
const loadLex = () => (LEX = LEX || (fs.existsSync(LEX_PATH) ? JSON.parse(fs.readFileSync(LEX_PATH, 'utf8')) : {}));
const PUNCT = /^[\s.,:;()[\]?!"'׳״—\-]+|[\s.,:;()[\]?!"'׳״—\-]+$/g;
const bare = (t) => t.replace(PUNCT, '');
const hasNikud = (t) => /[֑-ׇ]/.test(t);
export function mineLexicon(loadPairs) {
  // loadPairs(lang) -> iterable of [hebrewParagraph, variantParagraph]
  const out = {};
  for (const lang of ['en', 'fr', 'ru', 'ka']) {
    const tally = new Map();
    for (const [he, v] of loadPairs(lang)) {
      const a = he.replace(/<[^>]*>/g, ' ').split(/\s+/).filter((x) => /[א-ת]/.test(x) || /[\p{L}\d]/u.test(x));
      const b = v.replace(/<[^>]*>/g, ' ').split(/\s+/).filter((x) => /[\p{L}\d]/u.test(x));
      if (a.length !== b.length) continue;
      a.forEach((t, i) => {
        if (hasNikud(t)) return;
        const k = bare(t);
        if (!/^[א-ת׳״'"]{2,}$/.test(k)) return;
        const val = bare(b[i]).toLowerCase();
        if (!val) return;
        const m = tally.get(k) || new Map(); m.set(val, (m.get(val) || 0) + 1); tally.set(k, m);
      });
    }
    const lex = {};
    for (const [k, m] of tally) {
      const tot = [...m.values()].reduce((x, y) => x + y, 0);
      const [val, n] = [...m.entries()].sort((x, y) => y[1] - x[1])[0];
      if (tot >= 3 && n / tot >= 0.6) lex[k] = val;
    }
    out[lang] = lex;
  }
  fs.writeFileSync(LEX_PATH, JSON.stringify(out) + '\n');
  LEX = out;
  return out;
}

const NAMES = /^(Adonai|Adonaï|Hashem|Адонай|ადონაი)$/;
// The engine also "transliterates" Latin letters outside <b>..</b> (that is how &nbsp; once became &нбсп; in ru/ka), so
// entities and lexicon hits are swapped for private-use placeholders before it runs and restored afterwards.
export function trCommentary(lang, para) {
  const lex = loadLex()[lang] || {};
  const ents = [], lexHits = [];
  let s = numerals(para).replace(/&#?\w+;/g, (e) => `${ents.push(e) - 1}`);
  s = s.replace(/(^|[\s(\[>"'])([א-ת׳״'"]{2,})(?=$|[\s.,:;)\]?!<"'—-])/g, (all, pre, w) => {
    const m = /^(.*?)(['׳״"]*)$/.exec(w);
    const hit = lex[w] || lex[m[1]];
    if (!hit) return all;
    return pre + `${lexHits.push(hit) - 1}` + (lex[w] ? '' : m[2]);
  });
  let out = transliterate(s, SCHEMES[lang], newStats()).out.normalize('NFC');
  out = out.replace(/״/g, '"');
  out = out.replace(/(\p{L})["”](?=\p{L})/gu, '$1');
  out = out.replace(/\p{Lu}[\p{L}]*/gu, (w) => (NAMES.test(w) ? w : w.charAt(0).toLowerCase() + w.slice(1)));
  out = out.replace(/(\d+)/g, (_, i) => lexHits[+i]);
  // a citation "(Shemot Rabba 5,3)" is written in Title Case
  if (lang !== 'ka') out = out.replace(/\(([^()]*\d[^()]*)\)/g, (all, inner) => '(' + inner.replace(/(^|\s)(\p{L})/gu, (_, a, c) => a + c.toUpperCase()) + ')');
  if (lang !== 'ka') {
    let done = false, inTag = false;
    out = [...out].map((ch) => { if (ch === '<') inTag = true; if (inTag) { if (ch === '>') inTag = false; return ch; } if (!done && /\p{L}/u.test(ch)) { done = true; return ch.toUpperCase(); } return ch; }).join('');
  }
  if (lang === 'ka') out = out.replace(/<\/b>\s+/g, '</b>');
  return out.replace(/(\d+)/g, (_, i) => ents[+i]);
}
export { SCHEMES };
