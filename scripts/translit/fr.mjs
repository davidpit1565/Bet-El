// scripts/translit/fr.mjs
//
// French (Latin, accented) output scheme for the Hebrew phonological parser in core.mjs.
// Implements "convention A" from spec-fr.json / FR-NOTES.md: the style of the app's existing French
// transliteration of Chok LeYisrael (Rambam, Daf, Zohar, Tanya), Torah and Targum (98.8% of 5.4M tokens).
//
//   kh = chet and khaf, k = qof and dagesh-kaf, ch = shin, ts = tsadi, f = pe-rafe, v = bet-rafe/vav,
//   é = tsere / segol / vocal shva, ou = kubutz / shuruk, o = cholam / qamatz katan, a = patach / qamatz,
//   doubled letter = dagesh chazak, gu before é/i, ss between vowels, ï after a/o, Adonaï, hyphen for maqaf,
//   lower case except sentence start and Adonaï, silent aleph/ayin (no apostrophes), silent final he.
// Shva is vocal only: word start, after a vav-shuruk, under dagesh chazak, second of two shvas, and after
// the prefix ha- (see `post`). Everything Hebrew-specific is already resolved by core.mjs.

import { renderWord } from './core.mjs';

export const DEFAULTS = {
  qof: 'k',
  chet: 'kh',
  kafSoft: 'kh',
  gemDouble: true,
  mappiqKeepAfter: ['qamatz', 'qamatzKatan', 'cholam', 'hirik', 'qubutz', 'segol'], // vowel src after which a mappiq he is pronounced
  defaultVowel: 'a',
  capitalizeParagraph: true,
  shvaNaAfter: ['shuruk'],        // core: shva after vav-shuruk is vocal, after every other long vowel silent (omrim)
  prefixHaShva: true,             // ha + shva letter -> vocal (harébé, hamékabbél)
  divine: { tetragrammaton: 'Adonaï', hashem: 'Adonaï' },
};

// Unvocalized abbreviations whose reading is fixed (keyed by letters + geresh), per spec-fr.json specialWords.
const ABBREV = {
  'וגו׳': 'végomér', 'וכו׳': 'vékhouléi', 'כו׳': 'kouléi', 'גמ׳': 'Guémara', 'מתני׳': 'Michna',
  'ר׳': 'Rabbi',
};

const BASE = {
  aleph: '', bet: 'b', gimel: 'g', dalet: 'd', he: 'h', vav: 'v', zayin: 'z', chet: 'kh', tet: 't', yod: 'y',
  kaf: 'k', lamed: 'l', mem: 'm', nun: 'n', samekh: 's', ayin: '', pe: 'p', tsadi: 'ts', qof: 'k', resh: 'r',
  shin: 'ch', tav: 't',
};
const PREFIX_IDS = new Set(['vav', 'bet', 'lamed', 'kaf', 'mem', 'shin', 'dalet']);
const VOWEL_END = /[aeéèioïuê]$/;

export function createScheme(over = {}) {
  const o = { ...DEFAULTS, ...over };
  const scheme = {
    id: 'fr',
    options: o,
    core: { shvaNaAfter: o.shvaNaAfter, gemAfterShvaNa: false, qamatzHeuristic: false, strictDivine: true, identicalShvaNa: false },
    names: o.divine,
    maqaf: '-',
    consonant(p, ph, i) {
      if (p.mater && p.id === 'yod') return '';
      const id = p.id;
      if (p.unvoc) {
        if (id === 'aleph' || id === 'ayin') return 'a';
        if (id === 'vav') return 'v';
      }
      if (id === 'shin') return p.sin ? 's' : 'ch';
      if (id === 'bet') return p.soft ? 'v' : 'b';
      if (id === 'pe') return p.soft ? 'f' : 'p';
      if (id === 'kaf') return p.soft ? o.kafSoft : 'k';
      if (id === 'he') {
        if (p.mater) return '';
        if (p.mappik) {
          const pv = prevVowel(ph, i);
          const src = pv ? pv.src : null;
          if (pv && pv.furtive) return 'h';                     // gavoah
          if (src === 'tsere' && pv.via === 'yod') return 'h';  // léh, béréh, aléh (daf: 'éh' kept)
          return o.mappiqKeepAfter.includes(src) ? 'h' : '';
        }
        return 'h';
      }
      if (id === 'yod' && p.glide) return 'y';
      if (id === 'aleph' && p.mater) return '';
      if (id === 'qof') return o.qof;
      if (id === 'chet') return o.chet;
      return BASE[id];
    },
    vowel(p) {
      if (p.shva) return 'é';
      switch (p.id) {
        case 'e': return 'é';
        case 'u': return 'ou';
        default: return p.id; // a, i, o
      }
    },
    geminate(s) {
      if (!o.gemDouble) return s;
      return s + s; // bb, kk, chch, tsts, khkh
    },
    post(parts, ph) {
      // 1. consonants whose nikud is missing in the source get a default vowel
      for (let i = 0; i < parts.length; i++) {
        const part = parts[i];
        if (!(part.p && part.p.k === 'C' && part.p.vowelless && !part.p.unvoc && part.s)) continue;
        if (part.p.id === 'yod' || part.p.id === 'vav') { // ayyti, gavvna, vévlad: bare yod/vav after the same letter = doubled consonant, no vowel
          const pc = parts.slice(0, i).reverse().find((q) => q.p && q.p.k === 'C' && !q.p.mater);
          if (pc && pc.p.id === part.p.id) continue;
        }
        if (part.p.id === 'vav') { // ketiv הוא (hiv): bare vav before a final silent aleph
          const nx = parts.slice(i + 1).filter((q) => q.p && q.p.k === 'C');
          if (nx.length === 1 && nx[0].p.id === 'aleph') continue;
        }
        if (part.p.id === 'vav' && i === 0) {
          const nx = parts.slice(1).find((q) => q.p && q.p.k === 'C');
          part.s = nx && ['bet', 'mem', 'pe'].includes(nx.p.id) ? 'ou' : 'vé';
        } else part.s += o.defaultVowel;
      }
      // 1b. a word-final dagesh never doubles (at, amrat)
      for (let i = parts.length - 1; i >= 0; i--) {
        const q = parts[i].p;
        if (!q || q.k !== 'C' || q.mater || !parts[i].s) continue;
        if (q.gem && !parts.slice(i + 1).some((x) => x.p && x.p.k === 'V')) parts[i].s = parts[i].s.slice(0, parts[i].s.length / 2);
        break;
      }
      // 2. yod glide + final vav after qamatz: 'ayv' -> 'av' (alav, yadav)
      for (let i = 0; i < parts.length; i++) {
        const p = parts[i].p;
        if (p && p.k === 'C' && p.glide) {
          const nx = parts[i + 1] && parts[i + 1].p;
          if (p.afterSrc === 'qamatz' && nx && nx.k === 'C' && nx.id === 'vav' && i + 2 === parts.length) parts[i].s = '';
        }
      }
      // 3. ha- (after optional prefix letters) + shva letter: the shva is vocal (harébé, hamékabbél, léhakhézir)
      if (o.prefixHaShva) {
        let allPrefix = true;
        for (let i = 0; i < parts.length; i++) {
          const p = parts[i].p;
          if (!p || p.k !== 'C' || p.mater) continue;
          if (p.id === 'he' && allPrefix) {
            const nv = parts[i + 1] && parts[i + 1].p;
            if (nv && nv.k === 'V' && nv.src === 'patach') {
              let j = i + 2;
              while (j < parts.length && !(parts[j].p && parts[j].p.k === 'C' && !parts[j].p.mater)) j++;
              const q = parts[j] && parts[j].p;
              if (q && q.shvaNach && !q.final) {
                const isLast = !parts.slice(j + 1).some((x) => x.p && (x.p.k === 'C' ? !x.p.mater : x.p.k === 'V'));
                if (!isLast) parts[j].s += 'é';
              }
            }
            break;
          }
          if (!PREFIX_IDS.has(p.id)) break;
        }
      }
      // 4. gimel before é / i gets a u; doubled gimel: g + gu
      for (let i = 0; i < parts.length; i++) {
        const p = parts[i].p;
        if (!(p && p.k === 'C' && p.id === 'gimel')) continue;
        let j = i + 1;
        while (j < parts.length && parts[j].p && parts[j].p.k === 'C' && parts[j].s === '') j++; // silent aleph/ayin between
        const nx = parts[j];
        if (/^g+é$/.test(parts[i].s)) parts[i].s = (p.gem ? 'ggu' : 'gu') + 'é'; // ha-gué: shva added by step 3
        else if (nx && nx.p && nx.p.k === 'V' && /^[éi]/.test(nx.s)) parts[i].s = p.gem ? 'ggu' : 'gu';
      }
      // 5. ss between vowel sounds (samech / sin), ï after a/o on a silent aleph/ayin
      let acc = '';
      for (let i = 0; i < parts.length; i++) {
        const part = parts[i], p = part.p;
        if (p && p.k === 'C' && part.s === 's' && (p.id === 'samekh' || p.id === 'shin') && VOWEL_END.test(acc)) {
          let j = i + 1;
          while (j < parts.length && parts[j].p && parts[j].p.k === 'C' && parts[j].s === '') j++;
          const nx = parts[j];
          if (nx && nx.p && nx.p.k === 'V' && nx.s) part.s = 'ss';
        }
        if (p && p.k === 'C' && part.s === 'sé' && (p.id === 'samekh' || p.id === 'shin') && VOWEL_END.test(acc)) part.s = 'ssé'; // léhassékir
        if (p && p.k === 'V' && part.s === 'i' && /[ao]$/.test(acc)) {
          const pr = parts[i - 1] && parts[i - 1].p;
          if (pr && pr.k === 'C' && parts[i - 1].s === '' && (pr.id === 'aleph' || pr.id === 'ayin') && !pr.mater) part.s = 'ï';
        }
        acc += part.s;
      }
    },
    renderWord(ph, info) {
      if (info.kind === 'unvocalized') return renderUnvocalized(ph, scheme);
      if (ABBREV[info.skeleton]) return ABBREV[info.skeleton];
      return renderWord(ph, scheme, { ...info, bypass: true });
    },
    postText(s) { return o.capitalizeParagraph ? capitalizeSentences(s) : s; },
  };
  return scheme;
}

// Capitalise the first letter of the text and of every sentence (after . ? !). Tags are skipped.
export function capitalizeSentences(s) {
  let out = '', cap = true, inTag = false;
  for (const ch of s) {
    if (ch === '<') inTag = true;
    if (inTag) { out += ch; if (ch === '>') inTag = false; continue; }
    if (cap && /\p{L}/u.test(ch)) { out += ch.toUpperCase(); cap = false; continue; }
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
    if (!last && p.id !== 'aleph' && p.id !== 'ayin' && nx && !(nx.id === 'vav' || nx.id === 'yod' || nx.id === 'aleph' || nx.id === 'ayin') && s && !/[aeéiou]$/.test(s)) out += 'a';
  });
  return out;
}

function prevVowel(ph, i) { for (let j = i - 1; j >= 0; j--) if (ph[j].k === 'V') return ph[j]; return null; }

export const scheme = createScheme();
export default scheme;
