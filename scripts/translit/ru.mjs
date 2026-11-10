// scripts/translit/ru.mjs
//
// Russian (Cyrillic) output scheme for the Hebrew phonological parser in core.mjs.
// Dialect A of spec-ru.json (Torah / Zohar / Tanya / Rambam files of the app): Sephardi reading, strict
// 22-letter alphabet  а б в г д е з й и к л м н о п р с т у ф х ц ш  + hyphen. Never ь ъ ы э ю я ё ж ч щ,
// no apostrophes; aleph/ayin silent; he = г; chet/khaf = х; yod = й + vowel; dagesh chazak doubles.
// Capitals: first word of each unit (paragraph/heading) and Адонай only. See RU-NOTES.md, README.md.
import { renderWord } from './core.mjs';

export const DEFAULTS = {
  qamatzYodVav: 'av',     // ָיו -> ав (dialect A); 'ayv' would give айв (dialect B)
  shvaNa: 'е',
  defaultVowel: 'а',      // vowel for a consonant whose nikud is missing in the source
  gemAfterShvaNa: false,   // שְׁתֵּי = шете (data: dagesh after a vocal shva does not double)
  shvaNaAfter: ['shuruk', 'hirikYod'], // data: shva after qamatz/tsere/cholam is silent (кедма, гайта, йадха)
  capitalizeParagraph: true,
  divine: { tetragrammaton: 'Адонай', hashem: 'Адонай' },
};

const VOWEL = { a: 'а', e: 'е', i: 'и', o: 'о', u: 'у' };
const BASE = {
  aleph: '', bet: 'б', gimel: 'г', dalet: 'д', he: 'г', vav: 'в', zayin: 'з', chet: 'х', tet: 'т', yod: 'й',
  kaf: 'к', lamed: 'л', mem: 'м', nun: 'н', samekh: 'с', ayin: '', pe: 'п', tsadi: 'ц', qof: 'к', resh: 'р',
  shin: 'ш', tav: 'т',
};
// Unvocalized abbreviations whose reading is fixed (keyed by letters + geresh), expanded as in the app's data.
const ABBREV = { 'וגו׳': 'вегомер', 'וכו׳': 'вехулеи', 'כו׳': 'хулеи' };

// Vocalized abbreviations (וְגוֹ / וְכוּ without geresh) are read out as the app's data does.
const SPECIAL = { 'וגו': 'вегомер', 'וכו': 'вехулеи' };

export function createScheme(over = {}) {
  const o = { ...DEFAULTS, ...over };
  const scheme = {
    id: 'ru',
    options: o,
    core: { shvaNaAfter: o.shvaNaAfter, gemAfterShvaNa: o.gemAfterShvaNa, aramaicAlef: true },
    names: o.divine,
    maqaf: '-',
    consonant(p, ph, i) {
      if (p.mater) return '';                       // silent final he / yod / aleph used as vowel letter
      const id = p.id;
      if (p.unvoc) {
        if (id === 'aleph' || id === 'ayin') return 'а';
        if (id === 'vav') return 'в';
      }
      if (id === 'shin') return p.sin ? 'с' : 'ш';
      if (id === 'bet') return p.soft ? 'в' : 'б';
      if (id === 'pe') return p.soft ? 'ф' : 'п';
      if (id === 'kaf') return p.soft ? 'х' : 'к';
      return BASE[id];
    },
    vowel(p) { return p.shva ? o.shvaNa : VOWEL[p.id]; },
    geminate(s) { return s + s; },
    post(parts, ph) {
      // prefix + divine name: лаадонай / ваадонай / баадонай (no capital in the middle of a word)
      for (let i = 1; i < parts.length; i++) if (parts[i].p && parts[i].p.k === 'N') parts[i].s = parts[i].s.toLowerCase();
      for (let i = 0; i < parts.length; i++) {
        const part = parts[i];
        if (!(part.p && part.p.k === 'C' && part.p.vowelless && !part.p.unvoc && part.s)) continue;
        if (part.p.id === 'vav' && i === 0) {    // prefix vav without nikud: у- before b/m/p, else ве-
          const nx = parts.slice(1).find((q) => q.p && q.p.k === 'C');
          part.s = nx && ['bet', 'mem', 'pe'].includes(nx.p.id) ? 'у' : 'ве';
        } else part.s += o.defaultVowel;
      }
      // ָיו -> ав : the yod glide is not written before the final vav
      for (let i = 0; i < parts.length; i++) {
        const p = parts[i].p;
        if (p && p.k === 'C' && p.glide && o.qamatzYodVav === 'av') {
          const nx = parts[i + 1] && parts[i + 1].p;
          if (p.afterSrc === 'qamatz' && nx && nx.k === 'C' && nx.id === 'vav' && i + 2 === parts.length) parts[i].s = '';
        }
      }
    },
    renderWord(ph, info) {
      if (info.kind === 'unvocalized') return renderUnvocalized(ph, scheme);
      if (info.kind === 'abbrev' && ABBREV[info.skeleton]) return ABBREV[info.skeleton];
      if (info.kind === 'normal' && SPECIAL[info.skeleton]) return SPECIAL[info.skeleton];
      return renderWord(ph, scheme, { ...info, bypass: true });
    },
    postText(s) {
      // vocalized abbreviations written with an ASCII apostrophe: וְגוֹ' / וְכוּ'
      s = s.replace(/(?<![а-я])вего'/g, 'вегомер').replace(/(?<![а-я])веху'/g, 'вехулеи');
      return o.capitalizeParagraph ? capitalizeUnit(s) : s;
    },
  };
  return scheme;
}

// Capitalise the first letter of the unit (and after . ? ! sentence ends); Адонай is already capital.
export function capitalizeUnit(s) {
  let out = '', cap = true, inTag = false;
  for (const ch of s) {
    if (ch === '<') inTag = true;
    if (inTag) { out += ch; if (ch === '>') inTag = false; continue; }
    if (/[а-я]/.test(ch)) { out += cap ? ch.toUpperCase() : ch; cap = false; continue; }
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
    const base = p.id === 'aleph' || p.id === 'ayin' ? 'а' : null;
    if (p.id === 'vav' && i > 0 && !last) { out += 'о'; return; }
    if (p.id === 'yod' && i > 0 && !last) { out += 'и'; return; }
    const s = base !== null ? base : scheme.consonant({ ...p, soft: false, mater: false }, ph, 0);
    out += s;
    const nx = cs[i + 1];
    if (!last && p.id !== 'aleph' && p.id !== 'ayin' && nx && !(nx.id === 'vav' || nx.id === 'yod' || nx.id === 'aleph' || nx.id === 'ayin') && s && !/[аеиоу]$/.test(s)) out += 'а';
  });
  return out;
}

export const scheme = createScheme();
export default scheme;
