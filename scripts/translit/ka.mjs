// scripts/translit/ka.mjs
//
// Georgian (Mkhedruli) output scheme for the Hebrew phonological parser in core.mjs.
// Implements the RECOMMENDED scheme of KA-NOTES.md / spec-ka.json ("recommended"), NOT the baseline
// currently in the app's data (that one doubles letters and writes iii). No native speaker has reviewed it.
//
//   consonants: ბ(bet dagesh) ვ(bet rafe, vav) გ დ ჰ(he, mappiq/non-final only) ზ ხ(chet, kaf rafe, final kaf rafe)
//               ტ ი(yod) ქ(kaf dagesh, final kaf dagesh) ლ მ ნ ს(samekh, sin) ფ(pe, every form) ც(tsadi) კ(qof)
//               რ შ თ(tav) ; aleph / ayin silent (no apostrophes)
//   vowels:     patach ა, qamatz ა (katan ო), segol ე, tsere ე, hirik ი, cholam ო, qubutz/shuruk უ, chataf ა/ე/ო,
//               shva na ე, shva nach silent
//   no doubling for dagesh chazak; yod+hirik collapses (ისრაელ, ხაიმ, ვაიკრა), never more than two ი in a row;
//   final he silent (sounded only with mappiq); ָיו -> ავ; names: ადონაი / ჰაშემ; ელოჰიმ is an ordinary word;
//   lower-case Mkhedruli only (no capitals exist), hyphen for maqaf.
// To go back to the baseline engine, see spec-ka.json -> engineMaps (not implemented here).

import { renderWord } from './core.mjs';

export const DEFAULTS = {
  shvaNa: 'ე',
  defaultVowel: 'ა',      // vowel inserted after a consonant that lacks nikud inside a vocalized word
  gemAfterShvaNa: true,   // core: dagesh after a vocal shva counts as chazak (irrelevant without doubling, kept = en)
  shvaNaAfter: ['qamatz', 'tsere', 'cholam', 'shuruk', 'hirikYod'],
  divine: { tetragrammaton: 'ადონაი', hashem: 'ჰაშემ' },
  maxI: 2,
};

const VOWEL = { a: 'ა', e: 'ე', i: 'ი', o: 'ო', u: 'უ' };
const BASE = {
  aleph: '', bet: 'ბ', gimel: 'გ', dalet: 'დ', he: 'ჰ', vav: 'ვ', zayin: 'ზ', chet: 'ხ', tet: 'ტ', yod: 'ი',
  kaf: 'ქ', lamed: 'ლ', mem: 'მ', nun: 'ნ', samekh: 'ს', ayin: 'ყ', pe: 'ფ', tsadi: 'ც', qof: 'კ', resh: 'რ',
  shin: 'შ', tav: 'თ',
};
const ABBREV = { 'וגו׳': "ვეგო'", 'וכו׳': "ვეხუ'", 'כו׳': "ხუ'" };
const GEO_VOWEL_END = /[აეიოუ]$/;

export function createScheme(over = {}) {
  const o = { ...DEFAULTS, ...over };
  const scheme = {
    id: 'ka',
    options: o,
    core: { shvaNaAfter: o.shvaNaAfter, gemAfterShvaNa: o.gemAfterShvaNa, aramaicAlef: true },
    names: o.divine,
    maqaf: '-',
    consonant(p) {
      if (p.mater && p.id === 'yod') return '';
      const id = p.id;
      if (p.unvoc) {
        if (id === 'aleph') return 'ა'; if (id === 'ayin') return 'ყ';
        if (id === 'vav') return 'ვ';
      }
      if (id === 'shin') return p.sin ? 'ს' : 'შ';
      if (id === 'bet') return p.soft ? 'ვ' : 'ბ';
      if (id === 'kaf') return p.soft ? 'ხ' : 'ქ';     // rafe / final rafe -> ხ, dagesh -> ქ
      if (id === 'he') return p.mater ? '' : 'ჰ';       // final he silent unless mappiq (non-mater)
      if (id === 'aleph' && p.mater) return '';
      return BASE[id];
    },
    vowel(p) { return p.shva ? o.shvaNa : VOWEL[p.id]; },
    geminate(s) { return s; },                          // recommended scheme: dagesh chazak is NOT doubled
    post(parts, ph) {
      // missing nikud inside a vocalized word -> default vowel (prefix vav: უ before b/m/p, else ვე)
      for (let i = 0; i < parts.length; i++) {
        const part = parts[i];
        if (!(part.p && part.p.k === 'C' && part.p.vowelless && !part.p.unvoc && part.s)) continue;
        if (part.p.id === 'vav' && i === 0) {
          const nx = parts.slice(1).find((q) => q.p && q.p.k === 'C');
          part.s = nx && ['bet', 'mem', 'pe'].includes(nx.p.id) ? 'უ' : 'ვე';
        } else part.s += o.defaultVowel;
      }
      // qamatz + yod + final vav (ָיו) is read av: drop the yod
      for (let i = 0; i < parts.length; i++) {
        const p = parts[i].p;
        if (p && p.k === 'C' && p.glide) {
          const nx = parts[i + 1] && parts[i + 1].p;
          if (p.afterSrc === 'qamatz' && nx && nx.k === 'C' && nx.id === 'vav' && i + 2 === parts.length) parts[i].s = '';
        }
      }
      // consonant yod + hirik: one ი (יִ -> ი, יִּ -> ი)
      for (let i = 0; i < parts.length - 1; i++) {
        const p = parts[i].p, nx = parts[i + 1];
        if (p && p.k === 'C' && p.id === 'yod' && parts[i].s === 'ი' && nx.p && nx.p.k === 'V' && nx.s === 'ი') parts[i].s = '';
      }
    },
    renderWord(ph, info) {
      let r;
      if (info.kind === 'unvocalized') r = renderUnvocalized(ph, scheme);
      else if (info.kind === 'abbrev' && ABBREV[info.skeleton]) r = ABBREV[info.skeleton];
      else r = renderWord(ph, scheme, { ...info, bypass: true });
      return collapseI(r, o.maxI);
    },
    postText(s) { return s; },
  };
  return scheme;
}

// never more than maxI consecutive ი
export function collapseI(s, maxI = 2) {
  return s.replace(/ი{3,}/g, 'ი'.repeat(maxI));
}

function renderUnvocalized(ph, scheme) {
  const cs = ph.filter((p) => p.k === 'C');
  let out = '';
  cs.forEach((p, i) => {
    const last = i === cs.length - 1;
    const base = p.id === 'aleph' || p.id === 'ayin' ? 'ა' : p.id === 'he' && last ? 'ჰ' : null;
    if (p.id === 'vav' && i > 0 && !last) { out += 'ო'; return; }
    if (p.id === 'yod' && i > 0 && !last) { out += 'ი'; return; }
    const s = base !== null ? base : scheme.consonant({ ...p, soft: false }, ph, 0);
    out += s;
    const nx = cs[i + 1];
    if (!last && p.id !== 'aleph' && p.id !== 'ayin' && nx && !(nx.id === 'vav' || nx.id === 'yod' || nx.id === 'aleph' || nx.id === 'ayin') && s && !GEO_VOWEL_END.test(s)) out += 'ა';
  });
  return out;
}

export const scheme = createScheme();
export default scheme;
