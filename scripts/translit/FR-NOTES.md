# French transliteration: convention found in the existing data

Method: every `data/**/*.fr.json` was paired with its vocalized Hebrew sibling (same JSON shape), plus
`data/torah-fr.json` with `data/torah-data.json`, `PARSHA_FR_NAMES` in index.html with `data/leyning-data.json` `heName`,
and `data/prayers-fr.json` with the prayer texts in index.html. Paragraphs whose word counts matched were aligned word by
word (maqaf = `-`). A rule-based prototype (`fr-probe.py`) was then fitted to the pairs; it is the evidence tool, not the
production engine. Machine-readable result: `spec-fr.json`; test data: `corpus-fr.json` (441 entries).

Which files are real transliteration: chok-daf, chok-rambam, chok-zohar, chok-tanya, chok-leyisrael (the Hebrew/Aramaic
quotations), torah-fr, chok-benishchai, prayers-fr. NOT transliteration (French translation): chok-peleyoetz, chok-mesilat,
chok-orchot, chok-teshuva, chok-kedusha (ignored).

## Three conventions, not one

| | Sources | Tokens aligned | Prototype match |
|---|---|---|---|
| A (primary) | rambam, daf, zohar, tanya, leyisrael, torah-fr | 5,465,829 | 98.8% exact |
| B | chok-benishchai year1/2, prayers-fr | ~225k + 8k | 93-95% (with B overrides) |
| D | PARSHA_FR_NAMES + a few UI strings | 61 | not rule-derivable |

## Convention A in brief (what the language module should implement)

Consonants: aleph/ayin silent (their vowel is written, no apostrophe), bet-dagesh b / bet-rafe v, gimel g (gu before é/i),
dalet d, he h (final he silent), vav v, zayin z, **chet kh (same as khaf)**, tet t, yod y, kaf-dagesh k / kaf-rafe and final kh,
lamed l, mem m, nun n, samech s, pe-dagesh p / pe-rafe and final f, tsadi ts, **qof k** (never q: 379,504 tokens, 0 q),
resh r, shin ch, sin s, tav t (no th). Dagesh chazak doubles the letter (bb, kk, chch, tsts, yy ...; not aleph/he/chet/ayin/resh,
not word-initial/dagesh kal, not word-final): 1.24M tokens.

Vowels: patach a, qamatz a, qamatz katan o (explicit mark; word ending in kaf+lamed: kol; qamatz before chataf-qamatz),
segol **é**, tsere **é**, chirik i, cholam o, kubutz ou, shuruk ou, chataf patach a / segol é / qamatz o, shva na é, shva nach silent.
Mater yod/vav add nothing (tsere+yod = é: 226,607 vs 18 other; chirik+yod = i); no `ei`/`ay` for tsere-yod; patach+yod = ay.
Shva is vocal only: word-initial; after vav-shuruk; under dagesh chazak; second of two shvas; after prefix ha-.
Furtive patach: a before the consonant (rouakh, yodéa). Final he silent; mappiq-he = h after qamatz (59,338 vs 5) and silent after
patach/tsere (13,506). Samech/sin between vowels = ss (176,879 tokens). Gimel before é/i = gu (70,185). ï after a/o (hoïl, haïchcha).
Maqaf -> hyphen. No apostrophes inside words. Lower case except sentence/verse start and Adonaï.
Words: Adonaï, élohim, yisraél, moché, chabbat, tora, hachchém, ribbi; abbreviations expanded (ה' Adonaï, וגו' végomér, וכו' vékhouléi).

## Inconsistencies found (variant -> counts, majority first)

1. **Three systems in one app** (A vs B vs D above). B differs from A in: no accents (segol/tsere/shva = e), qof q (8,786 q vs 23 k in
   BIC), kaf/bet/pe not split by dagesh (tsarik, tob, apillou), kubutz u, no ss and no gu, furtive `kha`, `ayv`, `Adonai` without ï.
2. **Chet**: kh in every body text (458k tokens; 18 stray `h`), but `'h` in the reviewed UI names (Noa'h, 'Hayé Sarah, 'Houkat,
   Pin'has, Vaet'hanane). Khaf is kh in both. So the reviewed UI spelling and the body text disagree.
3. **Torah/Targum vs everything else**: `véïm`/`béïra`/`arbéïn` (ï after é) in torah-fr and Targum (e.g. véïm 170) versus
   `véim` 10,950 elsewhere; majority = no ï after é.
4. **Mappiq he in Aramaic**: dropped (la, ba, avou, lay) but kept in Hebrew (bah, lah, otah). Rule found by vowel: qamatz keeps h,
   patach/tsere/shuruk drop it; not by language.
5. **UI parsha names (D)**: no gemination (Vayéra, Vayigach, Matot, Nitsavim) but some hand-doubled (Massé, Ki-Tissa, Nasso);
   shva/tsere rendered inconsistently as é or e (Chémini/Béhar vs Toledot/Terouma/Metsora/Kedochim/Tetsavé), `è` once (Vayélèkh).
6. **Hanouka/Hanoucca**, **Roch 'Hodech**, **Edot HaMizra'h vs Édot HaMizrah**, **Hashem** (UI) vs `hachchém` (data), **Torah** (UI)
   vs `tora` (data), **Israël** (UI) vs `yisraél` (data) - UI strings capitalise and anglicise; data bodies do not.
7. **Capitalisation**: names are lower-case mid-sentence in data (yisraél 12,886 vs Yisraél 91; moché 4,267 vs Moché 39).
8. **B is not perfectly uniform**: prayers-fr has a few accents on tsere (lipné) while the rest of it and Ben Ish Chai use plain e.
9. **Shva after patach+yod**: `haynou` (leyisrael, הַיְנוּ) vs `hayéynou` (daf/tanya, הַיְינוּ): depends on the spelling.

## Not covered by rules (1.2% of A tokens)
Abbreviations and divine names (the largest items: ה' / יְיָ / יהוה rendered Adonaï ~12k, וגו' ~12k, וכו' ~4k), irregular forms
(הַלּוֶֹה, גּוָֹון), a few qamatz-katan words, and the yod-bearer shva above. See `specialWords` and `openQuestions` in spec-fr.json.

## Corpus
`corpus-fr.json`: 441 entries `{he, fr, src, conv, tag}`. `conv` A=284 (209 chosen to cover every letter/vowel/rule feature or the most
frequent words, plus random mid-frequency words and the special words), B=51, C=45 (prayers-fr, B-family), D=61 (PARSHA_FR_NAMES, also
as `src: index.html`). Hebrew has cantillation and surrounding punctuation stripped; French is verbatim apart from trimmed punctuation.
`src` is the first file/path where the aligned pair occurs.
