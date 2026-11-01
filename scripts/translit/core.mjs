// scripts/translit/core.mjs
//
// Language-neutral phonological parser for vocalized (nikud) Hebrew.
//
//   Hebrew text --tokenize()--> words / punctuation
//   Hebrew word --parseWord()--> phoneme list (consonants, vowels, flags)
//   phoneme list --renderWord(scheme)--> Latin / Cyrillic / Georgian string
//
// The parser knows NOTHING about the output language. It decides purely
// Hebrew-side questions (is this shva vocal or silent? is this dagesh a
// doubling one? is this vav a vowel? is this qamatz an "o"?). A language is a
// "scheme" module (see en.mjs) that maps phonemes to letters. No LLM, no
// network, fully deterministic.
//
// PHONEME OBJECTS
//   { k:'C', id, ch, final, soft, gem, dagesh, mater, glide, sin, vowelless }
//       id: 'aleph','bet','gimel','dalet','he','vav','zayin','chet','tet','yod',
//           'kaf','lamed','mem','nun','samekh','ayin','pe','tsadi','qof','resh',
//           'shin','tav'  (final forms share the id; use .final)
//       soft   : bet/kaf/pe WITHOUT dagesh (fricative: v / ch / f)
//       gem    : dagesh chazak (the consonant is doubled)
//       mater  : letter that is silent-capable (final he after a vowel,
//                yod after hirik/tsere/segol, aleph/he used as vowel letter)
//       glide  : yod after patach/qamatz/cholam with no vowel (ay, oy ...)
//       vowelless: consonant with no vowel mark that is not a legitimate
//                silent letter (i.e. nikud is missing; counted as "defective")
//   { k:'V', id:'a'|'e'|'i'|'o'|'u', src, via, long, shva, furtive }
//       src: qamatz | qamatzKatan | patach | tsere | segol | hirik | cholam |
//            qubutz | shuruk | shvaNa | hatafPatach | hatafSegol | hatafQamatz
//       via: null | 'vav' | 'yod' | 'he' | 'aleph'   (vowel letter, if any)
//       furtive: patach gnuva (already moved BEFORE its consonant)
//   { k:'X', s }   raw literal (geresh/gershayim quote etc.)
//   { k:'N', id }  divine name: 'tetragrammaton' | 'hashem'  (already whole word)

// ---------------------------------------------------------------- characters
const GERESH = '׳', GERSHAYIM = '״';
export const isLetter = (c) => c >= 'א' && c <= 'ת';
// marks we keep: vowels/shva/dagesh/holam-haser/rafe/shin dots/qamatz-qatan
const isKeepMark = (c) =>
  (c >= 'ְ' && c <= 'ּ') || c === 'ֿ' || c === 'ׁ' || c === 'ׂ' || c === 'ׇ';
// marks we consume and ignore: cantillation, meteg, paseq-adjacent, sof-pasuk-adjacent
const isIgnorableMark = (c) =>
  (c >= '֑' && c <= '֯') || c === 'ֽ' || c === 'ׄ' || c === 'ׅ' || c === '‍' || c === '‌';
const isMark = (c) => isKeepMark(c) || isIgnorableMark(c);
const hasVowelMark = (s) => /[ְ-ׇֻ]/.test(s);

export const LETTER_ID = {
  'א': 'aleph', 'ב': 'bet', 'ג': 'gimel', 'ד': 'dalet', 'ה': 'he', 'ו': 'vav', 'ז': 'zayin', 'ח': 'chet',
  'ט': 'tet', 'י': 'yod', 'כ': 'kaf', 'ך': 'kaf', 'ל': 'lamed', 'מ': 'mem', 'ם': 'mem', 'נ': 'nun', 'ן': 'nun',
  'ס': 'samekh', 'ע': 'ayin', 'פ': 'pe', 'ף': 'pe', 'צ': 'tsadi', 'ץ': 'tsadi', 'ק': 'qof', 'ר': 'resh',
  'ש': 'shin', 'ת': 'tav',
};
const FINAL_FORMS = new Set(['ך', 'ם', 'ן', 'ף', 'ץ']);
const BGDKPT = new Set(['bet', 'gimel', 'dalet', 'kaf', 'pe', 'tav']);
const FRICATIVE_VISIBLE = new Set(['bet', 'kaf', 'pe']); // soft form differs in speech
const GUTTURAL_NO_GEM = new Set(['aleph', 'he', 'ayin', 'resh', 'chet']);

// ------------------------------------------------------------------ tokenizer
// Returns [{t:'w', s}, {t:'maqaf'}, {t:'o', s}] where 'w' is a Hebrew word (marks kept, ZWJ and
// cantillation removed except we keep them harmlessly), gershayim inside abbreviations is encoded
// as U+05F4 and a trailing geresh as U+05F3. 'o' is any other text (punctuation, <b>, digits ...).
export function tokenize(text) {
  if (/[יִ-ﭏ]/.test(text)) text = text.normalize('NFD');
  const toks = [];
  let other = '';
  const flush = () => { if (other) { toks.push({ t: 'o', s: other }); other = ''; } };
  let i = 0;
  while (i < text.length) {
    const c = text[i];
    if (isLetter(c)) {
      flush();
      let j = i, w = '';
      while (j < text.length) {
        const d = text[j];
        if (isLetter(d) || isMark(d)) { w += d; j++; continue; }
        if ((d === '"' || d === GERSHAYIM) && w) {
          let k = j + 1, rest = '';
          while (k < text.length && (isLetter(text[k]) || isMark(text[k]))) { rest += text[k]; k++; }
          // gershayim = abbreviation/numeral: what follows the quote carries no vowel at all
          if (/[א-ת]/.test(rest) && !hasVowelMark(rest)) { w += GERSHAYIM; j++; continue; }
          break;
        }
        if ((d === "'" || d === GERESH) && w) {
          const nx = text[j + 1];
          if (!(nx && isLetter(nx))) { w += GERESH; j++; }
          break;
        }
        break;
      }
      toks.push({ t: 'w', s: w });
      i = j;
      continue;
    }
    if (isMark(c)) { i++; continue; } // stray mark
    if (c === '־') { flush(); toks.push({ t: 'maqaf' }); i++; continue; }
    if (c === '׃') { other += ':'; i++; continue; }
    if (c === '׀') { other += ' '; i++; continue; }
    other += c;
    i++;
  }
  flush();
  return toks;
}

// ---------------------------------------------------------------- clusters
function parseClusters(w) {
  const cl = [];
  let geresh = false;
  for (const ch of w) {
    if (ch === GERSHAYIM) { cl.push({ quote: true }); continue; }
    if (ch === GERESH) { geresh = true; continue; }
    if (isLetter(ch)) { cl.push({ ch, id: LETTER_ID[ch], v: null, dag: false, rafe: false, sin: null, kat: false }); continue; }
    const c = cl[cl.length - 1];
    if (!c || c.quote) continue;
    switch (ch) {
      case 'ְ': if (!c.v) c.v = 'shva'; break;
      case 'ֱ': c.v = 'hsegol'; break;
      case 'ֲ': c.v = 'hpatach'; break;
      case 'ֳ': c.v = 'hqamatz'; break;
      case 'ִ': c.v = 'hirik'; break;
      case 'ֵ': c.v = 'tsere'; break;
      case 'ֶ': c.v = 'segol'; break;
      case 'ַ': c.v = 'patach'; break;
      case 'ָ': c.v = 'qamatz'; break;
      case 'ֹ': case 'ֺ': c.v = 'cholam'; break;
      case 'ֻ': c.v = 'qubutz'; break;
      case 'ּ': c.dag = true; break;
      case 'ֿ': c.rafe = true; break;
      case 'ׁ': c.sin = 'shin'; break;
      case 'ׂ': c.sin = 'sin'; break;
      case 'ׇ': c.v = 'qamatz'; c.kat = true; break;
      default: break;
    }
  }
  return { cl, geresh };
}

// ------------------------------------------------------ katan / gadol heuristic
// Qamatz + a following letter that carries shva is ambiguous: qamatz katan (o) + silent shva
// (nokhri = "nochri") or qamatz gadol (a) + vocal shva (omru = "amaru"). Without semantic knowledge
// this is decided by morphology of the corpus (see README, "qamatz katan").
const PREFIXES = new Set(['ו', 'ש', 'ב', 'ל', 'כ', 'מ', 'ה', 'ד']);
const KATAN_LEX = new Set(['חכמה', 'חזקה', 'כרחך', 'כרחו', 'כרחה']);
const FINAL_TO_REG = { 'ך': 'כ', 'ם': 'מ', 'ן': 'נ', 'ף': 'פ', 'ץ': 'צ' };
function stripMarks(s) { return s.replace(/[^א-ת]/g, ''); }

// Returns 'katan' | 'gadol' | 'gadolNach' for a qamatz that is followed by a shva-bearing letter
// (caller guarantees cl[i].v==='qamatz', cl[i+1].v==='shva', and the shva letter is not the last).
// gadolNach = long a with a SILENT shva (Aramaic alma / amrinan).
function qamatzKind(cl, i, copts = DEFAULT_OPTIONS) {
  if (cl[i].kat) return 'katan';
  const L = cl.filter((c) => !c.quote);
  const idx = L.indexOf(cl[i]);
  const n = L.length;
  const skel = L.map((c) => c.ch).join('');
  const last = L[n - 1];
  const after = L[idx + 2];
  let pre = 0; // leading prefix letters (vav, she, be, le, ke, mi, ha, de) before the qamatz letter
  while (pre < idx && PREFIXES.has(L[pre].ch)) pre++;
  const prefixOnly = pre === idx;
  const stem = skel.slice(idx).replace(/[ךםןףץ]/g, (c) => FINAL_TO_REG[c]);
  if (KATAN_LEX.has(stem)) return 'katan';
  // Aramaic endings: alma, tzarchana, amrinan -> long a, silent shva
  if ((last.ch === 'א' && last.v === 'qamatz') || skel.endsWith('ינן')) return 'gadolNach';
  // option aramaicAlef: -ָא written as qamatz on the previous letter + bare final aleph (עָלְמָא alma, קָרְבָּא)
  if (copts.aramaicAlef && last.ch === 'א' && !last.v && !last.dag && n >= 3 && L[n - 2].v === 'qamatz') return 'gadolNach';
  // second-person suffix -cha: yad-e-cha, devar-e-cha, tzidkat-e-cha (open syllable, vocal shva)
  if (after && idx + 2 === n - 1 && after.ch === 'ך' && after.v === 'qamatz') return 'gadol';
  // article ה with qamatz (ha-reshut, ha-yeta)
  if (L[idx].ch === 'ה' && prefixOnly) return 'gadol';
  // verbs ending in shuruk (amru, barchu, yatz'u, halchu)
  if (last.ch === 'ו' && last.dag && !last.v) return 'gadol';
  // participles / hitpael: mem + shva before the stem letter (mevarchin), or mi + shva-letter (mitzterfin)
  if (idx >= 1 && L[idx - 1].ch === 'מ' && L[idx - 1].v === 'shva' && idx - 1 === pre) return 'gadol';
  if (idx >= 2 && L[idx - 2].ch === 'מ' && L[idx - 2].v === 'hirik' && L[idx - 1].v === 'shva' && idx - 2 === pre) return 'gadol';
  // feminine perfect (amra, nafla, hayta): qamatz, shva-letter, final ה without mappik
  if (idx + 2 === n - 1 && last.ch === 'ה' && !last.dag && !last.v) return 'gadol';
  // assimilated article after ב/ל with a resh stem: ba-rechov, la-retzu'ot
  if (prefixOnly && (L[idx].ch === 'ב' || L[idx].ch === 'ל') && L[idx + 1].ch === 'ר' && n - idx >= 5) return 'gadol';
  return 'katan'; // nouns / suffixed forms: nochri, achlo, tzorcho, korban, dofnei
}

// ---------------------------------------------------------------- word parse
const NUMERAL_PREV = new Set(['ובו', 'שעה', 'משעה', 'בשעה', 'סימן', 'ביום', 'שהוא', 'סעיף', 'אות', 'פרק', 'בליל', 'לשעה', 'מחצה']);
const NUMERAL_NEXT = new Set(['סעיפים', 'טפחים', 'ואילך', 'מקדש', 'זקף', 'קפות', 'מיני', 'פעמים', 'אמות', 'ימים', 'שבועות', 'דברים', 'מינים', 'חלקים']);

// Core (Hebrew-side) options. A scheme may override them through `scheme.core`.
//   shvaNaAfter: after which long-vowel classes a shva counts as VOCAL (na). Textbook rule = all of them;
//   many readers (and the app's existing transliteration) pronounce it silent after some (omrim, amru).
export const DEFAULT_OPTIONS = { strictDivine: false, qamatzHeuristic: true, identicalShvaNa: true, shvaNaAfter: ['qamatz', 'tsere', 'cholam', 'shuruk', 'hirikYod'], gemAfterShvaNa: false };

// Parse one Hebrew word token (string from tokenize()).
// ctx: { prev: stripped previous Hebrew word, next: stripped next Hebrew word, nextIsMaqaf }
// returns { ph:[...], kind:'normal'|'unvocalized'|'abbrev'|'letter'|'name', defective, ... }
export function parseWord(w, ctx = {}, copts = DEFAULT_OPTIONS) {
  ctx = { ...ctx, copts };
  { const fx = SOURCE_FIXES.get(w.normalize('NFC')); if (fx) w = fx.normalize('NFD'); }
  const { cl: clAll, geresh } = parseClusters(w);
  const letters = clAll.filter((c) => !c.quote);
  const hasQuote = clAll.some((c) => c.quote);
  const anyVowel = letters.some((c) => c.v || c.dag);
  const res = { ph: [], kind: 'normal', defective: false };

  // ---- divine name (ה' with optional vocalized prefix) and written tetragrammaton
  {
    const sk = letters.map((c) => c.ch).join('');
    if (geresh && !hasQuote && sk.endsWith('ה') && !letters[letters.length - 1].v && !letters[letters.length - 1].dag) {
      const pre = letters.slice(0, -1);
      if (pre.every((c) => PREFIXES.has(c.ch) && c.v) ) {
        const standalone = pre.length === 0;
        const asNumeral = standalone && (NUMERAL_PREV.has(ctx.prev || '') || (NUMERAL_NEXT.has(ctx.next || '') && !/^(אל|על)/.test(ctx.next || '')));
        if (!asNumeral) {
          const sub = parseNormal(clAll.slice(0, pre.length), ctx);
          res.ph = sub.ph.concat([{ k: 'N', id: 'hashem' }]);
          res.kind = 'name';
          return res;
        }
      }
    }
    const m = /^([ובכלמשה]*)(יהוה|יי)$/.exec(sk);
    // strictDivine: a word merely ending in יי (לשוויי, עילויי) is not the Name - the first yod of the Name has no vowel but shva/hataf
    const strictOk = !copts.strictDivine || m && !(letters[letters.length - 2] && /^(tsere|hirik|segol|patach|qamatz|cholam|qubutz)$/.test(letters[letters.length - 2].v || '') && m[2] === 'יי');
    if (m && strictOk && !geresh && !hasQuote) {
      const pre = letters.slice(0, m[1].length);
      const sub = pre.length ? parseNormal(clAll.slice(0, pre.length), ctx) : { ph: [] };
      res.ph = sub.ph.concat([{ k: 'N', id: 'tetragrammaton' }]);
      res.kind = 'name';
      return res;
    }
  }

  if (!anyVowel) {
    // nothing is vocalized -> abbreviation / numeral / citation word
    res.kind = hasQuote || geresh ? 'abbrev' : (letters.length === 1 ? 'letter' : 'unvocalized');
    res.ph = parseUnvocalized(clAll, geresh);
    return res;
  }
  if (hasQuote) {
    // mixed token: vocalized prefix + gershayim + bare letters (be-y"d, she-t"v). Parse each side on its own.
    const segs = [[]];
    for (const c of clAll) { if (c.quote) segs.push([]); else segs[segs.length - 1].push(c); }
    segs.forEach((seg, si) => {
      if (si > 0) res.ph.push({ k: 'X', s: '"' });
      if (!seg.length) return;
      const vocal = seg.some((c) => c.v || c.dag);
      res.ph.push(...(vocal ? parseNormal(seg, ctx).ph : parseUnvocalized(seg, false)));
    });
    if (geresh) res.ph.push({ k: 'X', s: "'" });
    res.kind = 'mixed';
    return res;
  }
  const r = parseNormal(clAll, ctx);
  if (geresh) r.ph.push({ k: 'X', s: "'" });
  return r;
}

// Known defects of the source text (a letter whose nikud is missing) -> the intended vocalization.
// Applied to the raw word before parsing; keys/values are compared after NFC normalisation.
export const SOURCE_FIXES = new Map([
  ['לְמשֶׁה', 'לְמֹשֶׁה'], ['בְּחשֶׁן', 'בְּחֹשֶׁן'], ['לִלְבּשׁ', 'לִלְבֹּשׁ'], ['וְיִלְבּשׁ', 'וְיִלְבֹּשׁ'],
  ['לְמַלֹּאות', 'לְמַלֹּאוֹת'], ['וְגו\u05F3', 'וְגוֹ\u05F3'], ['וְכו\u05F3', 'וְכוּ\u05F3'],
].map(([a, b]) => [a.normalize('NFC'), b.normalize('NFC')]));

function parseUnvocalized(cl, geresh) {
  const ph = [];
  const letters = cl.filter((c) => !c.quote);
  const single = letters.length === 1;
  cl.forEach((c, i) => {
    if (c.quote) { ph.push({ k: 'X', s: '"' }); return; }
    ph.push({ k: 'C', id: c.id, ch: c.ch, final: FINAL_FORMS.has(c.ch), soft: false, gem: false, dagesh: false, sin: c.sin === 'sin', unvoc: true, single, vowelless: true });
  });
  if (geresh) ph.push({ k: 'X', s: "'" });
  return ph;
}

// Build phonemes for a vocalized word (cluster list may contain {quote:true} separators).
function parseNormal(clAll, ctx) {
  const copts = ctx.copts || DEFAULT_OPTIONS;
  const out = { ph: [], kind: 'normal', defective: false };
  // split at quote separators (gershayim inside a vocalized word, e.g. zal = ז"ל written with nikud on the first letter)
  const cl = clAll.filter((c) => !c.quote);
  const n = cl.length;
  const role = new Array(n).fill('C'); // 'C' consonant, 'mV' matres vav (vowel), 'mY' silent yod
  const nextIsMaqaf = !!ctx.nextIsMaqaf;

  // --- vowel letters (matres lectionis)
  for (let i = 0; i < n; i++) {
    const c = cl[i];
    const prev = i > 0 ? cl[i - 1] : null;
    if (c.ch === 'ו') {
      if (c.dag && !c.v && (!prev || !prev.v || prev.v === 'shva' || role[i - 1] !== 'C')) role[i] = 'mV'; // shuruk
      else if (c.v === 'cholam' && !c.dag && (!prev || !prev.v || role[i - 1] !== 'C')) role[i] = 'mV'; // cholam male (vav is a vowel letter)
    } else if (c.ch === 'י' && !c.v && !c.dag && prev && role[i - 1] === 'C') {
      if (prev.v === 'hirik' || prev.v === 'tsere' || prev.v === 'segol') role[i] = 'mY';
    }
  }

  // --- qamatz katan decision
  const kind = new Array(n).fill(null); // 'katan' | 'gadol' | 'gadolNach'
  for (let i = 0; i < n; i++) {
    const c = cl[i];
    if (c.v === 'qamatz' && role[i] === 'C') {
      if (c.kat) { kind[i] = 'katan'; continue; }
      const nx = cl[i + 1];
      if (c.id === 'kaf' && nx && nx.ch === 'ל' && i + 2 === n && !nx.v) { // kol (also vechol, bechol ...)
        let ok = true; if (copts.qamatzHeuristic !== false) for (let q = 0; q < i; q++) if (!PREFIXES.has(cl[q].ch)) ok = false;
        if (ok) { kind[i] = 'katan'; continue; }
      }
      if (nx && nx.v === 'shva' && role[i + 1] === 'C' && i + 1 < n - 1) {
        if (copts.qamatzHeuristic !== false) kind[i] = qamatzKind(cl, i, copts); // option off: only explicit marks / kol (French)
      } else if (nx && nx.v === 'hqamatz') kind[i] = 'katan';
      else if (nx && nx.v === 'shva' && i + 1 === n - 1) kind[i] = null; // final shva nach, qamatz in closed final syllable: gadol
    }
  }

  // --- shva: vocal (na) or silent (nach)
  const shvaNa = new Array(n).fill(false);
  // class of the long vowel owned by cluster j (or attached via a vowel letter), else null
  const longClass = (j) => {
    const c = cl[j];
    if (role[j] !== 'C') return null;
    if (c.v === 'qamatz') return kind[j] !== 'katan' ? 'qamatz' : null;
    if (c.v === 'tsere') return 'tsere';
    if (c.v === 'cholam') return 'cholam';
    const nx = cl[j + 1];
    if (c.v === 'hirik' && nx && role[j + 1] === 'mY') return 'hirikYod';
    if (!c.v && nx && role[j + 1] === 'mV') return nx.v === 'cholam' ? 'cholam' : 'shuruk';
    return null;
  };
  const effVowelLong = (j) => longClass(j) !== null;
  const isLastTwoShva = (i) => i === n - 2 && cl[n - 1].v === 'shva' && role[n - 1] === 'C';
  for (let i = 0; i < n; i++) {
    const c = cl[i];
    if (c.v !== 'shva' || role[i] !== 'C') continue;
    const prev = i > 0 ? cl[i - 1] : null;
    const prevIdx = (() => { let j = i - 1; while (j >= 0 && role[j] !== 'C') j--; return j; })();
    // word-initial vowel letter (vav shuruk / cholam, e.g. u-she-) counts as a long vowel
    const leadClass = prevIdx < 0 && i > 0 && role[i - 1] === 'mV' ? (cl[i - 1].v === 'cholam' ? 'cholam' : 'shuruk') : null;
    let na;
    if (i === 0) na = true;
    else if (i === n - 1) na = false;
    else if (isLastTwoShva(i)) na = false;
    else if (c.dag && BGDKPT.has(c.id) ? chazakDagesh(cl, role, i) : c.dag && !BGDKPT.has(c.id)) na = true;
    else if (copts.identicalShvaNa !== false && cl[i + 1] && cl[i + 1].ch === c.ch && (cl[i + 1].v || role[i + 2] === 'mV')) na = true; // identical neighbours: hal-lu
    else if (prev && prev.v === 'shva' && role[i - 1] === 'C') na = !shvaNa[i - 1]; // two in a row: first silent, second vocal
    else if (prevIdx >= 0 && kind[prevIdx] === 'gadolNach') na = false;
    else if (leadClass && copts.shvaNaAfter.includes(leadClass)) na = true;
    else if (prevIdx >= 0 && longClass(prevIdx) && copts.shvaNaAfter.includes(longClass(prevIdx))) na = true;
    else na = false;
    shvaNa[i] = na;
  }

  // --- build phonemes
  const ph = out.ph;
  let lastShvaNa = false; // previous consonant carried a VOCAL shva
  let lastHadVowel = false; // previous consonant (or its matres) carried a full vowel
  let prevVowelSrc = null; // src of last real vowel (for glide/matres decisions)
  const skelLast = n - 1;
  for (let i = 0; i < n; i++) {
    const c = cl[i];
    const isFinal = i === skelLast;
    const prev = i > 0 ? cl[i - 1] : null;

    if (role[i] === 'mV') {
      const wantsO = c.v === 'cholam';
      ph.push({ k: 'V', id: wantsO ? 'o' : 'u', src: wantsO ? 'cholam' : 'shuruk', via: 'vav', long: true });
      lastHadVowel = true; prevVowelSrc = wantsO ? 'cholam' : 'shuruk';
      continue;
    }
    if (role[i] === 'mY') {
      const last = lastV(ph);
      if (last) last.via = 'yod';
      ph.push({ k: 'C', id: 'yod', ch: c.ch, mater: true, silentYod: true, final: false, soft: false, gem: false });
      continue; // keeps lastHadVowel
    }

    const id = c.id;
    const afterShvaNa = lastShvaNa; lastShvaNa = false;
    const strongCandidate = c.dag && i > 0 && !GUTTURAL_NO_GEM.has(id);
    let gem = false;
    if (strongCandidate) {
      if (BGDKPT.has(id)) gem = lastHadVowel || (copts.gemAfterShvaNa && afterShvaNa);
      else gem = true;
    }
    // mappik he (final he with dagesh) = real consonant, dagesh is not gemination
    const mappik = id === 'he' && c.dag && isFinal;
    if (mappik) gem = false;
    c.__gem = gem;

    const cons = {
      k: 'C', id, ch: c.ch, final: FINAL_FORMS.has(c.ch), dagesh: c.dag, gem,
      soft: FRICATIVE_VISIBLE.has(id) && !c.dag, sin: c.sin === 'sin', mappik,
    };

    // ---- patach gnuva (furtive): final ח ע ה(mappik) with patach after a long/closed vowel
    if (isFinal && c.v === 'patach' && (id === 'chet' || id === 'ayin' || mappik) && i > 0) {
      let pi = ph.length - 1; while (pi >= 0 && ph[pi].silentYod) pi--; // skip the mute yod of hirik/tsere-yod
      const pv = ph[pi];
      const longPrev = pv && pv.k === 'V' && (pv.via === 'vav' || pv.via === 'yod' || pv.src === 'tsere' || pv.src === 'cholam');
      if (longPrev) {
        ph.push({ k: 'V', id: 'a', src: 'patach', furtive: true, via: null });
        ph.push(cons);
        lastHadVowel = true; prevVowelSrc = 'patach';
        continue;
      }
    }

    // ---- final he / aleph quiescence
    if (isFinal && id === 'he' && !c.v && !c.dag && lastHadVowel) {
      const lv = lastV(ph);
      if (lv) { lv.hasHe = true; }
      cons.mater = true; cons.afterSrc = prevVowelSrc;
      ph.push(cons);
      continue;
    }

    // ---- yod glide (no vowel, after a vowel that is not hirik/tsere/segol)
    if (id === 'yod' && !c.v && !c.dag && i > 0 && lastHadVowel) {
      cons.glide = true; cons.afterSrc = prevVowelSrc; cons.final = false;
      ph.push(cons);
      continue;
    }

    ph.push(cons);
    if (!c.v) {
      // vowelless consonant. legit: aleph/he/vav-consonant carrying nothing is silent letter after vowel
      const nextRole = role[i + 1];
      const takenByMater = nextRole === 'mV';
      if (takenByMater) { cons.takesMater = true; }
      else if (id === 'aleph' && lastHadVowel) { cons.mater = true; }
      else if (!isFinal) { cons.vowelless = true; } // nikud is missing here (final letters may legitimately be vowelless)
      // dagesh forte w/o vowel before shuruk handled by mater branch
      lastHadVowel = takenByMater ? false : (id === 'aleph' ? lastHadVowel : false);
      if (takenByMater) lastHadVowel = false;
      continue;
    }
    // ---- the vowel itself
    const v = c.v;
    if (v === 'shva') {
      if (shvaNa[i]) { ph.push({ k: 'V', id: 'e', src: 'shvaNa', shva: true, via: null }); lastHadVowel = false; lastShvaNa = true; }
      else { cons.shvaNach = true; lastHadVowel = false; }
      prevVowelSrc = 'shva';
      continue;
    }
    let vo;
    switch (v) {
      case 'qamatz': vo = { id: kind[i] === 'katan' ? 'o' : 'a', src: kind[i] === 'katan' ? 'qamatzKatan' : 'qamatz' }; break;
      case 'patach': vo = { id: 'a', src: 'patach' }; break;
      case 'tsere': vo = { id: 'e', src: 'tsere' }; break;
      case 'segol': vo = { id: 'e', src: 'segol' }; break;
      case 'hirik': vo = { id: 'i', src: 'hirik' }; break;
      case 'cholam': vo = { id: 'o', src: 'cholam' }; break;
      case 'qubutz': vo = { id: 'u', src: 'qubutz' }; break;
      case 'hpatach': vo = { id: 'a', src: 'hatafPatach' }; break;
      case 'hsegol': vo = { id: 'e', src: 'hatafSegol' }; break;
      case 'hqamatz': vo = { id: 'o', src: 'hatafQamatz' }; break;
      default: vo = { id: 'a', src: 'patach' };
    }
    ph.push({ k: 'V', ...vo, via: null, long: ['qamatz', 'tsere', 'cholam'].includes(v) });
    lastHadVowel = true;
    prevVowelSrc = vo.src;
    if (kind[i] === 'gadolNach') cons.gadolNach = true;
  }
  out.defective = ph.some((p) => p.k === 'C' && p.vowelless);
  // fold lone leading vowels (vav shuruk / cholam alone)
  return out;
}

function lastV(ph) { for (let i = ph.length - 1; i >= 0; i--) if (ph[i].k === 'V') return ph[i]; return null; }

function chazakDagesh(cl, role, i) {
  // is the dagesh on cluster i a doubling dagesh? (bgdkpt only reach here)
  let j = i - 1; while (j >= 0 && role[j] !== 'C') j--;
  if (j < 0) return false;
  const p = cl[j];
  if (p.v && p.v !== 'shva') return true;
  if (role[i - 1] !== 'C') return true; // preceded by a vowel letter
  return false;
}

// ----------------------------------------------------------------- renderer
// Generic table-driven renderer. A scheme provides:
//   consonant(p)  -> string for a C phoneme (without doubling)
//   vowel(p, ctx) -> string for a V phoneme
//   geminate(str) -> doubled form
//   names         -> { tetragrammaton, hashem }
//   post(parts, wordInfo) -> optional rewrite hook over [{s, p}] before joining
// Schemes may instead export renderWord(ph, kind) themselves for total control.
export function renderWord(ph, scheme, info = {}) {
  if (scheme.renderWord && !info.bypass) return scheme.renderWord(ph, info);
  const parts = [];
  for (let i = 0; i < ph.length; i++) {
    const p = ph[i];
    if (p.k === 'X') { parts.push({ s: p.s, p }); continue; }
    if (p.k === 'N') { parts.push({ s: scheme.names[p.id] || '', p }); continue; }
    if (p.k === 'V') { parts.push({ s: scheme.vowel(p, ph, i), p }); continue; }
    let s = scheme.consonant(p, ph, i);
    if (p.gem && s) s = scheme.geminate(s, p);
    parts.push({ s, p });
  }
  if (scheme.post) scheme.post(parts, ph, info);
  return parts.map((x) => x.s).join('');
}

// Transliterate a free text string. Returns { out, stats }.
export function transliterate(text, scheme, stats = newStats()) {
  const toks = tokenize(text);
  // word context
  const wordIdx = toks.map((t, i) => (t.t === 'w' ? i : -1)).filter((i) => i >= 0);
  const strippedOf = (tk) => stripMarks(tk.s);
  let out = '';
  for (let ti = 0; ti < toks.length; ti++) {
    const t = toks[ti];
    if (t.t === 'o') { out += t.s; continue; }
    if (t.t === 'maqaf') { out += scheme.maqaf ?? '-'; continue; }
    // word
    const prevTok = (() => { for (let j = ti - 1; j >= 0; j--) { if (toks[j].t === 'w') return toks[j]; if (toks[j].t === 'o' && /[^\s"'(\[*<>\/b—-]/.test(toks[j].s.replace(/<\/?b>/g, ''))) return null; } return null; })();
    const nextTok = (() => { for (let j = ti + 1; j < toks.length; j++) { if (toks[j].t === 'w') return toks[j]; if (toks[j].t === 'o' && /[^\s"'(\[*<>\/b—-]/.test(toks[j].s.replace(/<\/?b>/g, ''))) return null; } return null; })();
    const ctx = {
      prev: prevTok ? strippedOf(prevTok).replace(/[׳״]/g, '') : '',
      next: nextTok ? strippedOf(nextTok).replace(/[׳״]/g, '') : '',
      nextIsMaqaf: toks[ti + 1] && toks[ti + 1].t === 'maqaf',
    };
    const w = parseWord(t.s, ctx, { ...DEFAULT_OPTIONS, ...(scheme.core || {}) });
    stats.words++;
    stats.byKind[w.kind] = (stats.byKind[w.kind] || 0) + 1;
    if (w.kind === 'unvocalized') { stats.unvocalized++; stats.unvocWords.set(stripMarks(t.s), (stats.unvocWords.get(stripMarks(t.s)) || 0) + 1); }
    if (w.kind === 'abbrev') stats.abbrev++;
    if (w.kind === 'letter') stats.letters++;
    if (w.defective) { stats.defective++; stats.defWords.set(t.s, (stats.defWords.get(t.s) || 0) + 1); }
    out += renderWord(w.ph, scheme, { kind: w.kind, skeleton: t.s.replace(/[^\u05D0-\u05EA\u05F3\u05F4]/g, '') });
  }
  if (scheme.postText) out = scheme.postText(out);
  // unknown characters (anything non-ASCII-printable that is not Hebrew) are reported
  for (const ch of text) {
    const cp = ch.codePointAt(0);
    if (cp > 0x7e && !(cp >= 0x0590 && cp <= 0x05ff) && cp !== 0x200d && cp !== 0x200c) stats.unknownChars.set(ch, (stats.unknownChars.get(ch) || 0) + 1);
  }
  return { out, stats };
}

export function newStats() {
  return { words: 0, unvocalized: 0, abbrev: 0, letters: 0, defective: 0, byKind: {}, unvocWords: new Map(), defWords: new Map(), unknownChars: new Map() };
}
