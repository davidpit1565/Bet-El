# Georgian (ka) transliteration - convention in the app today

Files: `spec-ka.json` (machine-readable, keyed by Hebrew letter/point names), `corpus-ka.json`
(389 verified word pairs `{he, ka, src, system}`), this note.

Method: every `*.ka.json` / `torah-ka.json` / `prayers-ka.json` / inline `TEHILLIM_KA` was word-aligned to its
vocalized Hebrew source (token counts must match; ~3.5M aligned word pairs, ~107k unique pairs analysed in
detail, 99.5% of A-system words and 93-98% of P/B words are explained by one DP aligner, so the numbers below are
solid). Nothing here comes from a native speaker. **EVIDENCE sections describe what the app does; the last
section is a RECOMMENDATION.**

## Evidence 1: there are three body systems, not one

| | A (baseline) | P (prayers-ka.json) | B (Ben Ish Chai) |
|---|---|---|---|
| where | Torah+Targum, Tehillim, Rambam, Zohar, Daf, Chok LeYisrael texts, Tanya (~98% of all text) | 60 prayer blocks | 51+47 BIC unit files |
| kaf with dagesh | კ (100%) | ქ (98%) | ქ (100%) |
| kaf rafe / final ך | ხ / ხ | ხ 66% ქ 33% / ქ 88% | ქ / ქ |
| qof | კ | ქ | ქ |
| pe with dagesh | პ | ფ | ფ |
| tet | ტ | თ (97%) | თ |
| bet rafe | ვ | ვ 78% / ბ 22% | ბ (never ვ) |
| final he after e/a | silent | silent 70-95% | ჰ (segol/tsere 100%) |
| tsadi | წ | წ | წ |
| chet, tav, shin/sin, vav, zayin | ხ თ შ/ს ვ ზ | same | same |

All three agree on: aleph/ayin silent, chet ხ, tav თ, patach ა, qamatz ა (katan ო), segol ე, tsere ე,
chirik ი, cholam ო, kubutz/shuruk უ, chataf ა/ე/ო, shuruk and cholam-male vav silent, divine name ადონაი.
Letters ღ ყ ძ ჟ ჩ ჭ ჯ are never used; A never uses ქ or ც (24 letters in ~18M characters).

## Evidence 2: doubled letters (dagesh chazak) are the rule, not the exception

Owner brief says community spellings avoid doubling. The data does the opposite: A doubles 99.5% of
non-begedkefet dageshim (n=240k) and 97.9% of begedkefet after a vowel (n=171k); B 99.3% / 99.9%. Dagesh kal
(word-initial or after silent shva) is single 100%. 562,503 A tokens contain a doubled letter
(e.g. ჰაზზე, ელლა, ათთა, შაბბათ, ჰაშშემ, თეჰილლიმ, ხაიიიმ, ვაიიიკრა). Only titles/UI avoid doubling.

## Evidence 3: yod - the "იი / იიი" problem

Yod is always ი, so initial or post-vowel `יִ` is **იი** and `יִּ` (yod+dagesh+chirik) is **იიი**:
17,713 A tokens start with იი (იისრაელ 5,792x, იიწხაკ, იითრო), 13,932 A tokens contain იიი
(ხაიიიმ, ვაიიიკრა, მიიიად, შენიიია), 748 contain იიიი. Prayers (P) write ისრაელ/ვაიქრა; titles write ისრაელ-style forms.

## Evidence 4: titles/UI follow a different convention from the body

`PARSHA_KA_NAMES`, `I18N.ka` (index.html) use community-style forms. Body vs title (A data):

| Hebrew | body | title/UI | differs in |
|---|---|---|---|
| נִצָּבִים | ნიწწავიმ | ნიცავიმ | წ->ც, no doubling |
| חַיֵּי | ხაიიე | ხაიე | no doubling |
| וַיִּקְרָא | ვაიიიკრა | ვაიკრა | იიი->ი |
| חֲנוּכָּה | ხანუკკა | ხანუქა | კ->ქ, no doubling |
| תְּהִלִּים | თეჰილლიმ | თეჰილიმ | no doubling |
| פִּנְחָס / פִּקּוּדֵי | პინხას / პეკუდე | ფინხას / ფეკუდე | პ->ფ |
| מִשְׁפָּטִים | მიშპატიმ | მიშფატიმ | პ->ფ |
| מְצֹרָע / וַיֵּצֵא | მეწორა / ვაიიეწე | მეცორა / ვაიცე | წ->ც |
| בְּרֵאשִׁית, שְׁמוֹת, בְּמִדְבַּר | same | same | none |

UI strings are not even self-consistent: ქ vs კ for kaf (ხანუქა, ბირქათ ჰამმაზონ, ბარუქ შეამარ vs ბირკათ ჰალევანა),
ტ vs თ (ტიკუნ რახელ vs თიკუნ ხაცოთ), ც (ხაცოთ) vs წ, ბეით იაკოვ (ei) vs body ბეთ, divine name ჰაშემ
(ლედავიდ ჰაშემ ორი) vs body ადონაი, `ვაიაკჰელ` uses a კჰ digraph found nowhere else. `პარაშა`: 0 uses as a
section name in index.html/prayers (UI uses `საკვირაო თავი`; `ფარაშათ` appears twice as a construct); torah-ka.json has
two unrelated hits (פָּרָשָׁיו).

## Evidence 5: data-hygiene problems (found while aligning)

* Ben Ish Chai: **22,042 of 481,601 tokens (4.6%) mix Latin a/e/i/o/u into Georgian words** (`Ქi aნaნ`, `ჰaმმiშქaნ`),
  52 files. Corpus excludes them.
* Mtavruli capitals at word starts (Ამარ, Ვეჰა): chok-daf 18,972 tokens, BIC 2,310, chok-leyisrael 1,093; none in Torah/Tehillim/prayers.
* Leaked markup (`ლო</big></strong>`, `<b>ბარეხ`) and digits/colons inside tokens in chok-* files.
* Torah ka keeps `:` for sof pasuk; Tehillim ka drops it. Maqaf -> `-` in both.
* Musar works (mesilat, orchot, peleyoetz, teshuva, reshit, kedusha) and the Ben Ish Chai biur are Georgian
  *translations*, not transliteration - they do not align and are not part of this spec.

## Evidence 6: other facts for the language module

* Divine name: `יְהֹוָה`(1,921) `יְיָ`(3,105) `ה׳`(1,859) `ה'`(768) `אֲדֹנָי` -> **ადონაი** in all systems; `הַשֵּׁם` -> ჰაშშემ (176) / ჰაშემ (4); `אֱלֹהִים` -> ელოჰიმ (1,528); `תּוֹרָה` -> თორა; `שַׁבָּת` -> შაბბათ.
* Shva na -> ე, nach -> silent. ე share: initial 100%, after shva 91.5%, after shuruk 93.6%, after short vowel 15.7% (mostly under a dagesh-chazak letter), after long vowel 2.6%. Exact generator rule unknown (see openQuestions).
* Aleph/ayin: 100% silent, no apostrophes. Final forms = non-final letters. Qamatz katan ო (כָּל -> კოლ). Final he silent in A; mappiq he -> ჰ.
* Diphthongs: patach/qamatz+yod final -> აი (ელაი, ადონაი), cholam+yod -> ოი (გოი), `ָיו` -> ავ (ალავ), segol/tsere/chirik+yod medial: yod silent (ენ, ბეთ, ელოჰიმ).

## Inconsistency summary (priority order)

1. Three body systems disagree on 8 sounds (table above).
2. Title/UI convention (ც, ქ, ფ, no doubling, ი) differs from every body system.
3. Doubling everywhere in body vs none in titles; იი/იიი runs.
4. Kaf-dagesh and qof merge into one letter in every system.
5. Latin letters, Mtavruli, markup inside Georgian tokens (BIC mainly).
6. UI self-inconsistency (ქ/კ, ტ/თ, ც/წ, ჰაშემ vs ადონაი).

## RECOMMENDED consistent scheme (recommendation, NOT evidence - needs a native/community reviewer)

Goal: one scheme that reproduces the 8 community-reviewed names (ხაიე სარა, ბერეშით, შემოთ, ვაიკრა, ბემიდბარ,
ნიცავიმ, ხანუქა, თეჰილიმ) and the owner's mapping notes (צ->ც, פ->ფ, ק->კ, hard kaf->ქ, ח/כ->ხ, ש->შ).

| Hebrew | recommended | rationale |
|---|---|---|
| ב dagesh / rafe | ბ / ვ | A and P agree; B merges |
| ג ד ה ז ל מ נ ס ר | გ დ ჰ ზ ლ მ ნ ს რ | unanimous |
| ח, כ rafe/final | ხ | unanimous (merged everywhere) |
| כּ (dagesh), final ךּ | ქ | titles (ხანუქა) + owner note; separates it from ק |
| ק | კ | owner note; A and titles |
| פ (both) | ფ | titles, P, B, owner note (drop A's პ) |
| צ / ץ | ც | titles + owner note (drop body წ) |
| ט / ת | ტ / თ | A; keeps tet and tav apart |
| ש / שׂ | შ / ს | unanimous |
| א ע | silent | unanimous |
| vowels | as today (patach ა, qamatz ა/ო, segol ე, tsere ე, chirik ი, cholam ო, kubutz/shuruk უ, chataf ა/ე/ო) | unanimous |
| shva na / nach | ე / silent | unanimous |
| dagesh chazak | **no doubling** | titles + owner note; doubling is only a body-text artefact |
| yod | ი, collapse runs: יִ -> ი, יִּ -> ი, never more than two ი | gives ისრაელ, ხაიმ, ვაიკრა |
| final he | silent unless mappiq (ჰ) | A; avoids B's ზეჰ/ბეჰ |
| ADONAI / השם / Elohim | ადონაი / ჰაშემ / ელოჰიმ | ადონაი unanimous; ჰაშემ matches titles |
| maqaf, sof pasuk | `-`, `:` (Torah only) | as today |
| script | lower-case Mkhedruli only; no Latin, no Mtavruli, no markup | hygiene |
| parasha | საკვირაო თავი (never პარაშა) | owner note |

`spec-ka.json -> recommended` contains the machine-readable form; `engineMaps` is the current baseline (A) so a
module can ship `scheme: "current"` first and switch to `"recommended"` once approved. Worked check:
חַיֵּי -> ხაიე, בְּרֵאשִׁית -> ბერეშით, וַיִּקְרָא -> ვაიკრა, נִצָּבִים -> ნიცავიმ, חֲנוּכָּה -> ხანუქა,
תְּהִלִּים -> თეჰილიმ. Open questions are in `spec-ka.json -> openQuestions` (18 items).
