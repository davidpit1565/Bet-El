// scripts/translit/en.mjs
//
// English (Latin) output scheme for the Hebrew phonological parser in core.mjs.
// Conventions follow the app's existing human/LLM transliteration (prayers-en.json, torah-en.json,
// data/chok-benishchai/**/*.en.json, data/chok-daf/*.en.json): Sephardic / Edot HaMizrach
// pronunciation, lowercase, doubled letters for dagesh chazak, "ch" for chet/khaf, "tz", "q" for qof,
// no apostrophes for aleph/ayin, Adonai for the written Name, hyphen for maqaf.
// See README.md for the evidence table and the options below.
//
// HOW TO ADD A LANGUAGE: copy this file, change the tables / options, export `scheme` (default) and
// `createScheme(opts)`. Required members: id, consonant(p), vowel(p), geminate(str), names, maqaf,
// postText(str). Everything Hebrew-specific is already resolved by core.mjs.

import { renderWord } from './core.mjs';

export const DEFAULTS = {
  bSoft: 'b',          // bet without dagesh
  kafSoft: 'k',       // khaf without dagesh (non-final)
  finalKafNach: 'k',  // final ך with shva (vowelless)
  pSoft: 'p',          // pe without dagesh
  gemDouble: true,     // dagesh chazak doubles the consonant
  finalHeAfter: { a: '', e: 'h', o: 'h', i: 'h', u: 'h', patach: 'h' }, // text for silent-capable final he, by preceding vowel id
  qamatzYodVav: 'ayv',  // ָיו  -> 'av' (or 'ayv')
  patachYod: 'y',      // ַי at word end -> 'y' (= 'ay') or 'i' (= 'ai')
  qamatzYod: 'i',     // ָי at word end -> 'i' (= 'ai', e.g. Adonai)
  tsereYod: 'e',       // ֵי (silent yod) -> 'e' (alt 'ei')
  segolYod: 'e',
  hirikYod: 'i',
  shvaNa: 'e',
  defaultVowel: 'a',   // vowel inserted after a consonant that lacks nikud inside a vocalized word
  gemAfterShvaNa: true,  // core option: dagesh in b/g/d/k/p/t right after a vocal shva counts as doubling
  shvaNaAfter: ['qamatz', 'tsere', 'cholam', 'shuruk', 'hirikYod'], // core option: shva after these long vowels is vocal
  capitalizeParagraph: true,
  capitalizeAfter: /([.?!]|:)\s+$/,   // sentence boundaries where the next word is capitalised
  divine: { tetragrammaton: 'Adonai', hashem: 'Hashem' },
  shinGem: 'shsh',     // doubled sh: 'shsh' | 'sh'
  qof: 'q',            // 'q' (prayers, Ben Ish Chai) or 'k' (Torah/Talmud files)
  tsadiGem: 'tztz',      // doubled tz: 'ttz' | 'tztz'
};

// Unvocalized abbreviations whose reading is fixed (keyed by letters + geresh).
const ABBREV = { 'וגו\u05F3': "vego'", 'וכו\u05F3': "veku'", 'כו\u05F3': "ku'" };

const BASE = {
  aleph: '', bet: 'b', gimel: 'g', dalet: 'd', he: 'h', vav: 'v', zayin: 'z', chet: 'ch', tet: 't', yod: 'y',
  kaf: 'k', lamed: 'l', mem: 'm', nun: 'n', samekh: 's', ayin: '', pe: 'p', tsadi: 'tz', qof: 'q', resh: 'r',
  shin: 'sh', tav: 't',
};

export function createScheme(over = {}) {
  const o = { ...DEFAULTS, ...over };
  const scheme = {
    id: 'en',
    options: o,
    core: { shvaNaAfter: o.shvaNaAfter, gemAfterShvaNa: o.gemAfterShvaNa, aramaicAlef: true },
    names: o.divine,
    maqaf: '-',
    consonant(p, ph, i) {
      if (p.mater && p.id === 'yod') return '';
      let id = p.id;
      if (p.unvoc) {
        if (id === 'aleph' || id === 'ayin') return p.single ? 'a' : 'a';
        if (id === 'vav') return 'v';
      }
      if (id === 'shin') return p.sin ? 's' : 'sh';
      if (id === 'bet') return p.soft ? o.bSoft : 'b';
      if (id === 'pe') return p.soft ? o.pSoft : 'p';
      if (id === 'kaf') {
        if (!p.soft) return 'k';
        if (p.final && p.shvaNach) return o.finalKafNach;
        return o.kafSoft;
      }
      if (id === 'he') {
        if (p.mater) {
          const key = p.afterSrc === 'patach' ? 'patach' : null;
          const prevV = prevVowel(ph, i);
          return key ? o.finalHeAfter.patach : (o.finalHeAfter[prevV ? prevV.id : 'a'] ?? '');
        }
        return 'h';
      }
      if (id === 'yod' && p.glide) {
        const isEnd = !ph.slice(i + 1).some((q) => q.k === 'C' || q.k === 'V');
        if (isEnd && p.afterSrc === 'qamatz') return o.qamatzYod;
        if (isEnd && p.afterSrc === 'patach') return o.patachYod;
        return 'y';
      }
      if (id === 'aleph' && p.mater) return '';
      if (id === 'qof') return o.qof;
      return BASE[id];
    },
    vowel(p, ph, i) {
      if (p.shva) return o.shvaNa;
      return p.id;
    },
    geminate(s, p) {
      if (!o.gemDouble) return s;
      if (s === 'tz') return o.tsadiGem === 'tztz' ? 'tztz' : o.tsadiGem === 'ttz' ? 'ttz' : 'tz';
      if (s === 'sh') return o.shinGem;
      if (s === 'ch') return 'ch';
      return s + s;
    },
    post(parts, ph) {
      // consonants whose nikud is missing in the source get a default vowel (counted in the stats)
      for (let i = 0; i < parts.length; i++) {
        const part = parts[i];
        if (!(part.p && part.p.k === 'C' && part.p.vowelless && !part.p.unvoc && part.s)) continue;
        if (part.p.id === 'vav' && i === 0) { // prefix vav without nikud: u- before b/m/p, else ve-
          const nx = parts.slice(1).find((q) => q.p && q.p.k === 'C');
          part.s = nx && ['bet', 'mem', 'pe'].includes(nx.p.id) ? 'u' : 've';
        } else part.s += o.defaultVowel;
      }
      // yod glide + final vav after qamatz: 'ayv' -> 'av'
      for (let i = 0; i < parts.length; i++) {
        const p = parts[i].p;
        if (p && p.k === 'C' && p.glide && o.qamatzYodVav === 'av') {
          const nx = parts[i + 1] && parts[i + 1].p;
          if (p.afterSrc === 'qamatz' && nx && nx.k === 'C' && nx.id === 'vav' && i + 2 === parts.length) parts[i].s = '';
        }
      }
    },
    // words without any nikud: consonants joined with a default 'a' (heuristic; counted in the stats)
    renderWord(ph, info) {
      if (info.kind === 'unvocalized') return renderUnvocalized(ph, scheme);
      if (info.kind === 'abbrev' && ABBREV[info.skeleton]) return ABBREV[info.skeleton];
      return renderWord(ph, scheme, { ...info, bypass: true });
    },
    postText(s) { return o.capitalizeParagraph ? capitalizeSentences(s) : s; },
  };
  return scheme;
}

// Capitalise the first letter of the text and of every sentence (after . ? !). HTML-ish tags are skipped.
export function capitalizeSentences(s) {
  let out = '', cap = true, inTag = false;
  for (const ch of s) {
    if (ch === '<') inTag = true;
    if (inTag) { out += ch; if (ch === '>') inTag = false; continue; }
    if (/[A-Za-z]/.test(ch)) { out += cap ? ch.toUpperCase() : ch; cap = false; continue; }
    if (/[.?!]/.test(ch)) cap = true;
    out += ch;
  }
  return out;
}

function renderUnvocalized(ph, scheme) {
  const cs = ph.filter((p) => p.k === 'C');
  let out = '';
  cs.forEach((p, i) => {
    const last = i === cs.length - 1;
    const base = p.id === 'aleph' || p.id === 'ayin' ? 'a' : p.id === 'he' && last ? 'h' : null;
    if (p.id === 'vav' && i > 0 && !last) { out += 'o'; return; }
    if (p.id === 'yod' && i > 0 && !last) { out += 'i'; return; }
    const s = base !== null ? base : scheme.consonant({ ...p, soft: false }, ph, 0);
    out += s;
    const nx = cs[i + 1];
    if (!last && p.id !== 'aleph' && p.id !== 'ayin' && nx && !(nx.id === 'vav' || nx.id === 'yod' || nx.id === 'aleph' || nx.id === 'ayin') && s && !/[aeiou]$/.test(s)) out += 'a';
  });
  return out;
}

function prevVowel(ph, i) { for (let j = i - 1; j >= 0; j--) if (ph[j].k === 'V') return ph[j]; return null; }

export const scheme = createScheme();
export default scheme;
