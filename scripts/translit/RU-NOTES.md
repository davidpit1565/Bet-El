# Russian transliteration convention (derived from existing Bet-El data)

Machine-readable form: `spec-ru.json`. Test corpus: `corpus-ru.json` (384 aligned
vocalized-Hebrew / Russian words; `dialect` = A / B / S; `ru` is lower-cased for
every source except `data/torah-ru.json`, capitalisation is a separate rule).

## Method
Word-aligned pairs were built from `data/torah-ru.json` (75k words, verse by verse,
token counts equal in 90% of verses), `data/chok-zohar|tanya|rambam/*.ru.json`
(0.9M words), `data/chok-benishchai/*/*.ru.json` (paragraphs + intro, 122k words)
and `data/prayers-ru.json` vs `data/siddur.json` (6.5k words). A throw-away
rule-based Hebrew->Cyrillic converter was run over all pairs and every disagreement
was classified; the rules in the spec are the ones that agree with the data.

## Three dialects, not one
* **A (default)** - Torah, Zohar, Tanya, Rambam. 95-99% of words equal the rule output.
  Sephardi/Edot-HaMizrach reading, strict alphabet of 22 letters
  `а б в г д е з й и к л м н о п р с т у ф х ц ш` + hyphen. Never ь ъ ы э ю я ё ж ч щ.
* **B** - Ben Ish Chai halacha bodies (also the closest genre to sa-harav). Only ~70% equal
  to A, uniformly in all 98 files: begadkefat fricatives written as stops
  (б п к: абал, шопек, как, мелек), final he written г (зег, гарбег), `ָיו` = айв,
  furtive patach ха (руха), apostrophe after abbreviations, and noisy inside one
  paragraph (шеккатаб / шекатав, гиннег / гине).
* **S** - `prayers-ru.json` is a patchwork: some keys follow A, newer ones use
  ь я э ё ѓ (эль, аль, коль, исраэль, Элоѓейну).

## Profile A in brief
Consonants: б (bet dagesh) / в (bet rafe), г, д, **г for ה**, в (vav), з, **х for ח and
כ/ך rafe**, т (ט and ת, with or without dagesh), й, к (כּ and ק), л, м, н, с (ס and שׂ),
ф (פ rafe) / п (פּ), ц, р, ш. Aleph and ayin are silent (no apostrophe, hiatus
unmarked: йааков).
Vowels: patach/qamatz gadol а, segol/tsere е, chirik и, cholam о, kubutz/shuruk у,
chataf-patach а, chataf-segol е, chataf-qamatz о, qamatz katan о (כָּל = кол 100%),
shva-na е, shva-nach nothing (follows real Hebrew syllabification: кедма, йадха).
Yod: always `й`+vowel (йа йе йи), never я/ю/е. Mater yod/he/vav are not written twice
(`ֵי` е, `ִי` и, `וֹ` о, `וּ` у, final silent he nothing). Diphthongs: `ַי` ай, `ָי` ай,
`ֹי` ой, `ָיו` ав (!), `ֵיהֶם` егем. Mappiq he = г (лаг, отаг). Furtive patach before the
consonant (ноах, руах, ганногеа).
Dagesh chazak doubles the letter (гашшамайим, ваййомер, шаббат, хаййим); dagesh qal
does not (берешит, мизбеах). Maqaf = hyphen. First word of every verse/unit
capitalised; only Адонай (and titles like Рабби) capitalised mid-sentence.
Special words: יְהֹוָה/יְיָ -> Адонай, לַיְיָ -> лаадонай, וְגוֹ -> вегомер,
וְכוּ -> вехулеи, אֱלֹהִים -> елогим, הוּא -> гу.

## Inconsistencies in the data (majority first)
* Word-initial dagesh chazak (because of the previous word): doubled 121x, single
  166x for non-begadkefat letters (лло/ло, ззот/зот) - unpredictable.
* Qamatz katan: `חָכְמָה` хохма (torah) vs хахма (zohar/tanya/rambam, 142 words);
  vayyaqom-type verbs ваййаком (torah, 102) vs вайякам (zohar, 35).
* He+shva-nach mid-word: г in 389, silent in 27 (ейе, вейе, непах).
* Zohar/Tanya/Rambam contain a few corrupted/odd tokens (гвоавн, галлвое).
* Profile B: stop-vs-fricative and gemination vary inside one paragraph; `ь я э ё`
  appear only in S and in the Russian *translations* (biur) - not transliteration.
* Tetragrammaton: Адонай capital; real אֲדֹנָי lower-case (only 16 tokens).

## Open questions
See `openQuestions` in `spec-ru.json` (profile choice for sa-harav, word-initial
dagesh, qamatz katan source, shva na/nach validation, geresh letters ג׳ ז׳ צ׳ not in
the data, abbreviations).

## Implementation (ru.mjs) and results
`node scripts/build-sa-harav-translit.mjs --lang ru` -> `data/sa-harav/oc/<n>.ru.json` (511 files, 7.0 MB), dialect A.
* Corpus match (`node scripts/translit/corpus-compare-ru.mjs`): **274/287 = 95.5%** of dialect-A words
  (`corpus-ru.json`). Remaining 13 diffs are source noise or unknowable: Zohar words with a missing mappiq
  (`דְּאוּקְמוּהַ` ... -> `-уаг`), missing vowels (`זְה`, `הַזְּה`), shva na/nach noise (`הַרְבֵּה` гаребе,
  `וְדִיקְנִה`), `חָכְמָה` хахма (corpus is inconsistent with torah's хохма), bare `לַה` (= ל+ה' in the
  Zohar), `יֱהֹוִה` = Елогим (not implemented, 4 words in Torah).
* Choices measured on that corpus: shva after qamatz/tsere/cholam is silent (`shvaNaAfter: [shuruk, hirikYod]`,
  evidence in spec-ru.json: 785/362/181 silent vs 16/28/1 vocal); dagesh after a vocal shva does not double
  (`שְׁתֵּי` = шете); `וְגוֹ`/`וְכוּ` (+ ASCII `'`) = вегомер / вехулеи; prefix + divine name = `лаадонай`.
* Core change: new opt-in option `aramaicAlef` (default off, so English is byte-identical) - `-ָא` written as
  qamatz on the last consonant + bare aleph (`בְּעָלְמָא` = беалма, 152x in sa-harav). English still reads it
  as `beolma`; enabling the option in en.mjs would fix that.
* Tests: `node scripts/translit/test-ru.mjs` (56 hand-checked cases). Spot-reader: `sample-ru.mjs <siman> [skip] [count]`.
* Known weaknesses: numerals/abbreviations are kept as letters with their quotes (`й"т`, `г'`, `ткк"т`);
  ה' as a numeral is only recognised through the NUMERAL_PREV/NEXT lists in core.mjs (else = Адонай);
  qamatz katan vs gadol is heuristic; word-initial dagesh from the previous word is never doubled.
