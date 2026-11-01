# Deterministic Hebrew transliteration (nikud -> Latin)

Rule-based, no LLM, no network. Used for Shulchan Aruch HaRav
(`node scripts/build-sa-harav-translit.mjs --lang en`). Transliteration only - never translation.

```
core.mjs          language-neutral phonological parser (+ generic renderer, tokenizer, stats)
en.mjs            English output scheme: tables + options (this is the template for new languages)
test.mjs          68 hand-checked cases          -> node scripts/translit/test.mjs
corpus-compare.mjs   word-by-word match vs the app's existing transliteration
sweep.mjs         one-factor option sweep used for tuning
../build-sa-harav-translit.mjs   generator (+ stats report)
```

## Pipeline
1. `tokenize()` splits text into Hebrew words / maqaf / other text (punctuation, `<b>`, digits, brackets are
   passed through untouched). Cantillation, meteg and ZWJ are ignored. `"`/`״` inside a word is gershayim only
   when what follows it carries no vowels (י"ט, זַ"ל); otherwise it is a quote mark (`בְּ"בָרוּךְ`).
2. `parseWord()` turns a word into phonemes: `C` (consonant: id, `soft`, `gem`, `mater`, `glide`, `final`,
   `shvaNach`), `V` (vowel: a/e/i/o/u + `src`, `via`), `X` (literal), `N` (divine name). It resolves
   everything that is a Hebrew question: vowel letters, shva na/nach, dagesh qal/chazak, furtive patach,
   qamatz katan/gadol, final he/aleph. `renderWord()` + a scheme turn phonemes into letters.
3. Words with no nikud at all are classified `unvocalized` (consonants with default `a`), `abbrev`
   (gershayim/geresh), `letter` (single letter) or `mixed` (vocalized prefix + bare letters). Consonants
   missing nikud inside a vocalized word are `defective` (default vowel `a`, prefix vav `u`/`ve`).
   All are counted by the generator. `SOURCE_FIXES` (core.mjs) repairs known one-letter defects of the source.

## Rules implemented (core.mjs)
* **Shva na**: word start; after a long vowel (qamatz gadol, tsere, cholam, shuruk, hirik+yod) - option
  `shvaNaAfter`; under a dagesh-chazak letter; second of two shvas mid-word; first of two identical letters
  (hal-lu). **Shva nach**: otherwise; word-final; both shvas of a final pair (וַיֵּבְךְּ). NB: the textbook rule is
  *first* shva silent / *second* vocal - the task text said "first = na", which is not Hebrew grammar; we follow grammar.
* **Dagesh**: bgdkpt letter doubles (chazak) iff the previous letter in the word carries a full vowel (or a vocal
  shva, option `gemAfterShvaNa`, which gives שְׁתֵּי = shette); otherwise qal. Every other letter with dagesh
  mid-word doubles; guttural/resh never; mappik he (אוֹתָהּ) is a real `h`.
* **Vav**: shuruk (dagesh, no vowel) and cholam-vav after a vowelless consonant are vowel letters; vav after a
  consonant that has any vowel/shva (מִצְוֹת, עֲוֹן) is a consonant. Yod after hirik/tsere/segol is mute; after
  patach/qamatz it is a glide (`ay`, `ayv`).
* **Patach gnuva**: final ח/ע(/mappik ה) with patach after a long vowel or vowel letter is read before the
  consonant (ruach, sheliach, shamea).
* **Final he**: silent after qamatz (tora, melaka), sounded after segol/tsere/cholam/patach (mosheh, mah).
* **Qamatz katan** (heuristic, `qamatzKind`): `כָּל` (+prefixes) = kol; qamatz before a vocal-looking shva is
  *gadol* for verbs ending in shuruk (ameru), feminine perfect (hayeta), participles with מְ/מִ (mebarekin),
  article ה (hareshut), `-cha` nouns, Aramaic `-a`/`-inan`; everything else (nouns, suffixed forms) is *katan*
  (nokri, achlo, tzorke). Lexicon `KATAN_LEX` for חכמה/חזקה. Expect ~0.3-0.5% of words to be arguable.
* **Divine name**: `יהוה/יְהֹוָה/יי` -> `Adonai` (app convention, 697x in prayers-en.json); `ה'` (with optional
  vocalized prefix) -> `Hashem` unless it is a numeral (סעיף ה', next word סעיפים, ...). Context lists
  `NUMERAL_PREV/NUMERAL_NEXT`. `אֱלֹהִים`, `אֲדֹנָי` are ordinary words (`elohim`, `adonai`).

## English conventions and the evidence (en.mjs)
Evidence = `data/prayers-en.json` (the app's prayers, same Hebrew in `data/siddur.json`),
`data/chok-benishchai/**/*.en.json` (halacha - the sister genre, 2,000 halachot), `torah-en.json`,
`chok-daf/*.en.json`. The app's data is itself inconsistent across generations, so the halacha+prayers style
(newest, same owner, same genre) was chosen: **no spirantization** (`b`,`k`,`p` for bet/kaf/pe always:
abotenu, baruk, melek, apillu; v only for vav), `ch` = chet only, final ךְ = `k` (tzarik), `q` = qof, `tz`,
aleph/ayin silent (no apostrophes: kaari, melaka), doubled consonant for dagesh chazak (shebbiktab, hattora,
shennittan; `tztz` as in shetztzarik, `shsh`), `ayv` for ָיו (bemitzvotayv in prayers-en, alayv in daf),
`Adonai`, lowercase except sentence starts, `-` for maqaf, abbreviations keep their quotes (z"l, y"t).
Torah/Talmud files use the older style (v, ch, f, k for qof, no final h): `en.mjs` can reproduce it with
options (see below).

### Corpus match (exact word match, case/punctuation-insensitive, unvocalized + abbreviation words excluded)
| corpus | words | first run (v/ch/f defaults, early bugs) | final, chosen style | final, legacy options* |
|---|---|---|---|---|
| Ben Ish Chai (halacha) | 209,697 | 68.2% | **96.6%** | - |
| prayers-en / siddur | 2,311 | - | 78.2% | - |
| Torah | 68,152 | 86.1% | 61.5% | **94.3%** |
| Chok-daf (Mishna/Gemara) | 1,765,662 | 84.7% | 69.1% | **92.9%** |
\* `{"bSoft":"v","kafSoft":"ch","finalKafNach":"ch","pSoft":"f","qof":"k","qamatzYodVav":"av","shinGem":"sh",
finalHeAfter: all ""}`. Run: `node scripts/translit/corpus-compare.mjs [--corpus bic,torah,daf,siddur] [--opts JSON] [--show N]`.

Accepted systematic differences (BIC, ~3.4%): the existing text is LLM-made and inconsistent: kaf sometimes
`ch` (lachen/laken), final he dropped/kept at random (ze/zeh), furtive patach often ignored (rucha vs ruach), vav
read as silent in מִצְוֹת (mitzot vs mitzvot), qamatz katan read as `a` (hannakeri vs hannokri), Aramaic
alma/amerinan, ketiv `הִוא`, abbreviations expanded (גמ׳ -> Gemara). We prefer phonetic correctness there.

## Options (en.mjs `DEFAULTS`)
`bSoft kafSoft finalKafNach pSoft qof` (spirantization), `finalHeAfter{a,e,o,i,u,patach}`, `qamatzYodVav`
(`ayv`|`av`), `patachYod`/`qamatzYod` (`y`|`i`), `shvaNa`, `shvaNaAfter` (core), `gemAfterShvaNa` (core),
`shinGem`, `tsadiGem`, `defaultVowel`, `capitalizeParagraph`, `divine{tetragrammaton,hashem}`.

## Adding a language (fr, ru, ka, ...)
1. Copy `en.mjs` to `<lang>.mjs`; keep the export shape: `scheme` (default) and `createScheme(opts)`.
2. Replace the tables/options. The scheme interface used by `renderWord` in core.mjs:
   `consonant(p, ph, i)`, `vowel(p, ph, i)`, `geminate(str, p)`, `names{tetragrammaton,hashem}`, `maqaf`,
   `post(parts, ph, info)` (rewrite hook over `{s,p}` parts), `postText(str)`, optional
   `renderWord(ph, info)` (total control; `info.kind` = normal|unvocalized|abbrev|letter|mixed|name,
   `info.skeleton` = raw letters) and optional `core` (overrides for `shvaNaAfter`, `gemAfterShvaNa`).
   Phoneme fields are documented at the top of core.mjs (`soft`, `gem`, `mater`, `glide`, `furtive`, `final`,
   `vowelless`, vowel `src`/`via`, `afterSrc`).
3. Cyrillic/Georgian have no digraph problems for gemination: return the doubled/long form in `geminate`;
   a language without a distinct `ch`/`kh` sound should map `chet` and `kaf` in `consonant`.
4. Add a block to `test.mjs` (or a `test-<lang>.mjs`), run `node scripts/build-sa-harav-translit.mjs --lang <lang>`,
   then `node scripts/generate-data-manifest.mjs`.
Core must stay language-neutral: if a rule is about Hebrew (not about spelling), change `core.mjs` and re-run all
languages' tests.

## Known weaknesses
* Qamatz katan vs gadol before a shva is heuristic (see above); words outside the patterns default to katan.
* A shva after a long vowel is always vocal (textbook rule), which reads slightly formal (omerim).
* Source defects (a missing vowel) get a default `a`; known ones are patched in `SOURCE_FIXES`.
* Unvocalized loan-words (Yiddish/German) and numerals are consonant skeletons (`y"t`, `qrvb"tz`).
* Ketiv/qere, stress, and the vav of הִוא are not modelled.
