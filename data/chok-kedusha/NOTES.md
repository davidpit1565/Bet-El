# Sha'arei Kedusha — Chok LeYisrael data notes

## Scope
Only Introduction, Part 1, and Part 2 were fetched (per instructions). Parts 3
and 4 (prophecy / Ruach HaKodesh material) were never requested from Sefaria
and are not present anywhere in this directory.

## Source verification
- `/api/shape/Sha'arei_Kedusha` confirmed: Introduction = 1 section, 13
  chapters; Part 1 = 6 sub-sections with chapters `[14,15,10,15,9,25]`; Part 2
  = 8 sub-sections with chapters `[13,9,28,64,35,13,19,26]`. Matches the
  numbers given in the task exactly.
- `/api/v2/raw/index/Sha%27arei_Kedusha` schema shows Introduction is a
  depth-1 `JaggedArrayNode` (`sectionNames: ["Paragraph"]`) and Part 1–4 are
  each a `SchemaNode` wrapping a depth-2 default `JaggedArrayNode` with
  `sectionNames: ["Shaar", "Paragraph"]`. **There are no per-Shaar named
  schema nodes/titles** — contrary to the task's working assumption, Sefaria
  does not expose individual gate names as index titles. The gate names used
  below are Hebrew ordinals lifted from the text's own in-line headers
  ("השער הראשון", "השער השני", ...), paired with an English "Gate N" label.

## Ref addressing scheme (confirmed by sampling + full fetch)
- Introduction: 1-level, `Sha'arei Kedusha, Introduction N` for N = 1..13.
- Part 1 / Part 2: 2-level, `Sha'arei Kedusha, Part 1 S:P` (or `Part 2 S:P`)
  where S = Shaar (gate) number (1-based) and P = paragraph number within
  that gate (1-based). E.g. `Sha'arei Kedusha, Part 1 1:1`, `Part 1 2:4`.
- Sefaria also accepts paragraph *ranges* within a gate, e.g.
  `Sha'arei Kedusha, Part 1 1:1-3`, and echoes that exact string back as the
  canonical `ref`. This is used below for the one merged unit per gate.

Confirmed by pulling three whole-node fetches instead of ~292 individual
calls: `Sha'arei_Kedusha,_Introduction`, `..._Part_1`, `..._Part_2` each
return the full nested `he` array in one request, with sub-array lengths
matching the shape endpoint exactly.

## Header paragraphs (the "Part 1 1:1 returns a placeholder" issue)
Confirmed and handled. Every one of the 14 gates (6 in Part 1, 8 in Part 2)
opens with 2 short title/topic paragraphs before real running prose begins,
e.g. for Part 1, Gate 2: paragraph 1 = `"השער השני:"` ("Gate Two:"),
paragraph 2 = `"בפגם הנמשך על ידי מדות המגונות:"` ("On the blemish caused by
bad character traits:") — both are title-like, and paragraph 3 is where the
real multi-sentence content starts. Gate 1 of each Part additionally opens
with a "Part label" paragraph (`"החלק ראשון:"` / `"החלק שני"`) before its own
gate-title paragraph(s):
- Part 1, Gate 1: 2 header paragraphs (Part label + a single paragraph that
  combines the gate label and its topic sentence).
- Part 2, Gate 1: 3 header paragraphs (Part label, gate label, topic
  sentence — kept as 3 separate paragraphs by Sefaria's segmentation here,
  unlike Part 1 Gate 1 where the translator/editor merged label+topic into
  one paragraph).
- All other gates (Part 1 gates 2–6, Part 2 gates 2–8): 2 header paragraphs
  (gate label + topic sentence).

Every one of these 14 cases was individually inspected (not just assumed)
before building the data.

**Handling: merged forward, not discarded.** For each gate, the header
paragraph(s) were merged into the *first* addressable unit's paragraph array,
alongside that gate's first real content paragraph, so no text is lost and no
addressable unit is a bare placeholder like "Gate Two:". That merged unit's
`ref` is a Sefaria range (e.g. `Sha'arei Kedusha, Part 1 2:1-3`); all
subsequent units in that gate are single Sefaria paragraphs.

## Granularity / unit count
Sefaria's finest addressable level for this text is the single "Paragraph"
under each Shaar (or under the flat Introduction) — there is no finer
sub-paragraph split available. After merging header paragraphs forward:

- Introduction: 13 units (no merges needed; even the short opening line,
  "אמר הצעיר חיים בן כבוד הרב יוסף ויטאל זלה\"ה", is genuine authorial text,
  not a placeholder, so it was left as its own unit).
- Part 1: 76 units (raw paragraphs 89, minus 2 header paragraphs merged away
  per gate × 6 gates = 12 → 76... i.e. per-gate content counts
  12,13,8,13,7,23).
- Part 2: 190 units (per-gate content counts 10,7,26,62,33,11,17,24).
- **Total: 279 addressable units.**

This is coarser than Reshit Chokhmah's 328 units or Sha'arei Teshuvah's 339,
simply because Sefaria's Sha'arei Kedusha text is not segmented as finely at
the paragraph level in the long gates (e.g. Part 2 Gate 4 alone is 62 units
of continuous halachic/ethical exposition). This is the finest level Sefaria
exposes; no further split was invented.

## Vocalization (nikud) — UNVOCALIZED, confirmed across the entire text
All 308 raw Hebrew paragraphs fetched (13 Introduction + 89 Part 1 + 206 Part
2, before merging) were scanned for Unicode combining marks in U+0591–U+05C7.
**Zero matches.** The Sefaria "he" text for Sha'arei Kedusha carries no
vowel points anywhere — not "mostly vocalized with some gaps" but completely
unvocalized, consistently, in Introduction, Part 1, and Part 2 alike.

Examples (plain consonantal text, no nekudot):
1. Introduction 2 (opening): `ראיתי בני עלייה, והם מועטים, משתוקקים לעלות...`
2. Part 1, Gate 1, content: `אשכילך ואורך כמה גדלה רעת האדם בעשותו אחת מכל מצות השם...`
3. Part 2, Gate 8, content: `<b>החלק הראשון</b> במצות עשה: ...`

**Consequence for the app:** same as Reshit Chokhmah — this text must ship
with the "אֵין מַהֲדוּרָה מְנֻקֶּדֶת" (no vocalized edition available) notice
rather than being presented as vocalized. There is no partial-vocalization
edge case to special-case; it is uniform across the whole book.

## Sub-section naming (judgment call)
Because Sefaria exposes no per-gate title nodes, `section` values are
`"Introduction"` / `"Gate 1"`..`"Gate 6"` (Part 1) / `"Gate 1"`..`"Gate 8"`
(Part 2), and `heSection` values are `"הקדמה"` / `"השער הראשון"`..
`"השער הששי"` / `"השער הראשון"`..`"השער השמיני"` — the same ordinal
Hebrew phrasing the text itself uses for each gate's own header line.
"Gate" was chosen as the English rendering of שער (also Sefaria's own
published English translation of this work uses "Gate One", "Gate Two", …).

## Output
- `order.json`: flat array, 279 entries, each
  `{"part","section","heSection","ch","ref"}`. `ch` is 1-based *within the
  addressable-unit numbering used here* (i.e. the merged header+first-content
  unit is ch 1, not the raw Sefaria paragraph number).
- `0.json`–`6.json`: 7 block files, chunk size 40 (block 6 has the remaining
  19), each `{ref: [heParagraph, ...]}`, matching indices
  `[N*40, N*40+40)` into `order.json`. Block boundaries and ref lists were
  programmatically verified to line up with `order.json` and every unit's
  paragraph array was checked non-empty.
- No refs were skipped outright; the only paragraphs not appearing as their
  own standalone unit are the 14 gates' 2–3 header paragraphs, each merged
  into its gate's first unit as described above.
