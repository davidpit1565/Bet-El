# Ben Ish Chai — integration analysis & plan (built)

Source: a standalone reference app the user uploaded
(`ben-ish-chai-app-v242.zip`, ~4.5MB) containing per-parasha Ben Ish
Chai halachot data. This document analyzes that data against Bet-El's
existing Chok LeYisrael architecture and proposes how a "Ben Ish Chai"
track would be added, matching the already-planned mention in
`CLAUDE.md`'s Halacha pace question ("בְּקָרוֹב: מַסְלוּל בֶּן אִישׁ חַי
יִצְטָרֵף כְּאוֹפְּצְיָה נוֹסֶפֶת").

**Status: built**, using the v244 package (see the update below) as the
data source. See `CLAUDE.md`'s Architecture essentials for the shipped
shape (`S.halachaWork`, `data/chok-benishchai*`, `ckBenishchaiLabel`/
`bicBody`/`bicToggleComm`). The sections below are kept as the design
record of how the decision was reached; "open questions" at the bottom
are marked with what was actually decided.

## Update: v244 replaces v242 — most gaps closed

The user later uploaded `ben-ish-chai-app-v244.zip` (~22MB uncompressed),
a materially more complete package than v242. Everything below the
original "What's in the source zip" section still describes the data
*shape* correctly, but several concrete numbers/gaps changed:

- **Year 2 now exists**: `content/year2/*.json`, 47 files, same shape
  as year1. This resolves open question #1 below — both years can be
  built together now, not just year1.
- **Coverage is far more complete**:
  - **Year 1: 100% of the 54 canonical parshiot** (52 files - some
    combined-pairs pre-merged same as before, plus a `Chanukah` bonus
    file and a `V'Zot HaBerachah` file that a naive name-match missed
    on first pass but is present). None of the original 6 gaps remain.
  - **Year 2: 46/54 (85%)** — real gaps are **Bamidbar, Devarim,
    Nitzavim, Vayeilech, Ha'azinu, Vezot Haberakhah** (everything from
    Bamidbar and Devarim except Vaetchanan..Ki Tavo). Behar/Bechukotai
    is present as a merged file, same pattern as year1.
  - One year2 file, **Vayeshev, is intentionally a single explanatory
    entry, not a gap**: the source itself notes Rabbi Yosef Chaim taught
    Chanukah laws in that slot every year instead of a regular halacha
    set for Vayeshev in Shana Sheniya - this is authentic to the sefer,
    not missing data.
  - Total: **2,002 halachot** across both years (matches the package's
    own README).
- **Nikkud is already done** — `content/nikud.json` (4MB) is a
  complete lookup, keyed `"<track>|<parasha_en>|<chapter-or-'intro'>"`
  → array of fully vocalized paragraphs, covering all 2,002 halachot +
  ~99 intros (2,100 entries). This replaces the earlier plan to run
  Dicta's Nakdan — the vocalized text just needs joining in at
  data-prep time, keyed the same way the raw content is (this answers
  open question #3: nikkud is already available, no separate pass
  needed).
- **New optional-value data files**, not essential for a first version
  but worth knowing about:
  - `content/glossary.json` (2,065 entries): global hard-word →
    plain-Hebrew definition pairs.
  - `content/ctxgloss.json` (105 entries): per-halacha contextual
    overrides for words whose meaning depends on that specific passage.
  - `content/sefaria_refs.json` (2,100 entries): a canonical Sefaria
    URL per halacha/intro — useful for a "view on Sefaria" / precise
    citation link, matching how Bet-El already cites sources elsewhere.
  - `content/topics.json`: halachot tagged by topic (e.g. "mezuzah" →
    22 references across both years) — a "browse by topic" feature,
    not needed for the daily-reading flow itself.
  - `content/ambig.json` (69 entries): looks like the source's own
    nikkud-disambiguation working data, not something Bet-El needs to
    consume directly since the final vocalized text is already in
    `nikud.json`.
- **`content/week/` and `content/daily/`** are *not* a per-day division
  of halachot (that would have solved the pacing question outright) -
  they're just cached snapshots of "which parasha is this calendar
  week/day" from Sefaria's calendar API, used by the standalone app's
  own "today" view. The even-split-across-6-days design below is still
  needed; nothing in v244 pre-computes it.
- Per-parasha halacha counts are still highly uneven (year1: 9-58,
  year2: 12-40 excluding the 1-entry Vayeshev special case), so the
  even-split-with-remainder-front-loaded approach below remains the
  right design, not a fixed N/day.

## What's in the source zip

- `content/year1/<Parasha>.json` × 46 files (45 real parshiot + one
  `Chanukah.json` bonus). No `year2/` folder exists yet, even though the
  zip's own bundled `index.html` already has UI (tabs, CSS) built for a
  `year2` track — it's a planned-but-undelivered second cycle, not
  something we can build against yet.
- Each parasha file:
  ```json
  {
    "track": "year1", "track_he": "שנה א׳",
    "parasha_en": "Bereshit", "parasha_he": "בראשית", "slug": "Bereshit",
    "intro": { "paragraphs": [...] },
    "halachot": [
      { "chapter": 1, "paragraphs": [...],
        "clarification": { "explanation": "...", "takeaways": ["...", "..."] } },
      ...
    ]
  }
  ```
  `chapter` is a 1-based sequential halacha number within that parasha
  (matches how the printed sefer itself numbers halachot per shaar/parasha).
- 878 halachot total (850 across the 45 real parshiot + 28 in the
  Chanukah bonus file). Per-parasha count ranges from **9 (Shemot) to
  30 (Bamidbar)**, median 18, mean ~19.
- Text is **completely unvocalized** (0% nikkud across ~92,000 Hebrew
  words checked) — same situation Pele Yoetz was in before this
  session's fix. If read-aloud-quality nikkud is wanted, the same
  Dicta Nakdan pipeline used for Pele Yoetz applies here directly.
- Every halacha also carries a `clarification` block (plain-language
  `explanation` + bullet `takeaways`) — genuinely new content type Bet-El
  doesn't currently have a UI pattern for (closest existing thing is the
  commentary-panel pattern used for Rashi/Or HaChaim etc., but those are
  original-language sources, not a modern explanatory gloss).

## Coverage gap: 6 parshiot have no content at all

Comparing the 45 "real" parasha files against Bet-El's canonical
54-name parasha list (`data/chok-leyisrael-index.json` → `parshiot`),
these are genuinely missing (not just merged elsewhere):

**Noach, Vayishlach, Tetzaveh, Vayikra, Tzav, Vezot Haberakhah**

(Tazria/Metzora, Achrei Mot/Kedoshim, and Behar/Bechukotai are *not*
missing — the source pre-merged each of those pairs into one file,
which is fine since Bet-El's own combined-week logic, `ckSplitPair`,
already expects to sometimes treat two parshiot as one unit.)

This is ~11% of the annual cycle with a content hole. Whatever we build
needs to either wait for that content, or ship with those 6 weeks
gracefully falling back (e.g. hidden from the pace-picker's coverage,
or a "content coming soon" state) rather than crashing.

## How this maps onto Bet-El's existing architecture

Two possible existing patterns to model this on, and why one fits much
better than the other:

- **Not like Rambam/Zohar/Gemara daf** (`CYC`-based): those run on a
  pure absolute-date anchor + fixed pace, completely untethered from
  which parasha week it is — they never "restart" with a new parasha.
  Ben Ish Chai is explicitly parasha-bound (the user's whole ask is
  "always organized by the parshiot"), so this model is wrong for it.

- **Like Torah/Nevi'im/Ketuvim/Gemara-legacy-fallback** (parasha-keyed,
  `CHOK.schedule[parashaKey][day]`): each parasha's content is split
  into `sun/mon/tue/wed/thu/night/fri` buckets **ahead of time**, baked
  into static JSON, not computed live in the browser. Confirmed by
  reading `data/chok-leyisrael-index.json`'s `schedule` object — Torah's
  per-day boundaries are hand-curated at data-prep time from a printed
  source, then just looked up at runtime. Ben Ish Chai should follow
  this exact shape: a precomputed `schedule[parasha][day].benishchai`
  array, added by a one-time data-prep script (not a runtime split).

The difference from Torah: there's no external "printed sheet"
authority for how Ben Ish Chai's halachot divide across 6 days (unlike
the Torah verse boundaries, which come from an existing convention).
So instead of hand-curating, the data-prep script should **evenly
distribute each parasha's halachot across its 6 days**, front-loading
the remainder (same shape as the monthly Tehillim division, which also
isn't evenly divisible by day-count):

```
n = halachot in this parasha; days = 6 (sun..fri)
base = floor(n/days); extra = n % days
first `extra` days get (base+1) halachot, the rest get `base`
```

Examples: Bereshit (10) → `[2,2,2,2,1,1]`. Bamidbar (30, evenly
divisible) → `[5,5,5,5,5,5]`. Shemot (9) → `[2,2,2,1,1,1]`.

For a combined-week year (e.g. Vayakhel+Pekudei read together), reuse
the exact same `ckKeysOf`/`ckSplitPair` machinery Torah already uses:
concatenate both parshiot's halacha lists into one combined-week list,
then run the same even-split across the 6 days — "the tracks tied to
the parasha run one after the other," per the existing code comment.

## Update: accounting for real Yom Tov days (no data change needed)

The user pushed back on the naive average (total halachot ÷ 52 weeks ÷ 6
days): Shabbat is already excluded structurally (Chok LeYisrael only has
sun-fri slots), but actual Yom Tov weekdays are days nobody studies
through the app either - and that shouldn't be computed from specific
calendar dates (which vary year to year), but reasoned about as a
property of Chok LeYisrael's own weekly structure.

Checked the app's existing `chokIsYomTov()` (index.html, "Yom Tov
make-up" section, ~line 3495): it already defines exactly this - real
Chag days only, explicitly excluding Chol HaMoed and Erev (both
ordinary study days), via hebcal's flags, automatically adjusting for
Israel (`il`) vs diaspora day-counts. Per year that's:

- **Diaspora**: Rosh Hashana(2) + Yom Kippur(1) + Sukkot 1-2(2) +
  Shmini Atzeret(1) + Simchat Torah(1) + Pesach 1-2,7-8(4) + Shavuot
  1-2(2) = **13 chag-days/year**.
- **Israel**: Rosh Hashana(2) + Yom Kippur(1) + Sukkot day 1(1) +
  Shmini Atzeret/Simchat Torah combined(1) + Pesach 1,7(2) + Shavuot(1)
  = **8 chag-days/year**.

Roughly 6/7 of those land on an actual weekday rather than falling on
Shabbat itself (an approximation - the exact count depends on which of
the 14 possible Hebrew-year patterns a given year is, not something
worth hand-computing per year for a planning estimate). That's ~11
lost study-weekdays/year in the diaspora, ~7 in Israel.

Corrected average (year1, 52 weeks × 6 = 312 nominal slots, 1,026
halachot): **~3.41/day (diaspora)**, **~3.36/day (Israel)** - up from
the naive 3.29/day. Year2 (47 weeks, 948 halachot): **~3.50/day
(diaspora)**, **~3.45/day (Israel)** - up from 3.36/day naive. Full
per-parasha breakdown with this correction is in the published report
artifact from this conversation.

**Conclusion: this does not change the data-prep design above.** The
per-parasha 6-day schedule still has to fill all 6 slots, because at
data-prep time there's no way to know which specific weekday a given
year's Rosh Hashana/Pesach/etc. will land on - that's exactly why
`chokIsYomTov()` checks the real calendar at runtime instead of being
baked into static data. Once Ben Ish Chai is wired into the same
`chokMissedSlots()`/make-up flow that Torah and Halacha already use, it
inherits this handling automatically - a Yom Tov weekday's portion
already gets folded into the next day's make-up prompt, generically,
with no extra work needed for this specific track.

## Where the pace choice and UI would plug in

- **Settings → קֶצֶב לִמּוּד → הֲלָכָה**: currently a 2-way toggle
  (Rambam 3-year vs 1-year track). This is exactly the slot
  `CLAUDE.md`'s pending note refers to — Ben Ish Chai would become a
  third option here (and in the first-open pace wizard,
  `CK_PACE_UI.halachaQ`), likely swapping the whole Halacha section's
  content source rather than sitting alongside Rambam.
- **Reader**: the Halacha section (`chokSourceLine`/`prayerBlock`-style
  rendering) would need a new `kind:'benishchai'` branch parallel to
  `kind:'rambam'`, sourced from `schedule[parasha][day].benishchai`
  instead of the date-driven `CYC.rambam` index.
- **`clarification` (explanation + takeaways)**: needs a new UI
  affordance — most natural fit is an expandable panel under each
  halacha paragraph, similar in spirit to the existing commentary
  toggle buttons (Rashi/Or HaChaim) but its own visual treatment since
  it's explanatory prose in the reader's own language, not a historical
  source text.
- **5-language translation**: per this repo's existing convention,
  every new UI string (section label, pace-question copy, "no content
  yet" fallback) needs he/en/fr/ru/ka entries. The halacha body text
  itself stays Hebrew-only (like Rambam/Musar), machine nikkud aside.

## Open questions — how each was resolved when built

1. ~~Only year1 for now, or wait for year2?~~ **Resolved by v244** —
   both years shipped as parallel choices (`S.bicYear`).
2. **Year 2's 6 missing parshiot** (Bamidbar, Devarim, Nitzavim,
   Vayeilech, Ha'azinu, Vezot Haberakhah) — **shipped with a graceful
   gap**: those weeks simply have no `halacha` section at all when
   `S.halachaWork==='benishchai'` and `S.bicYear==='year2'` (verified with
   a Playwright check - no crash, the section list is just one entry
   shorter that week). Not backfilled.
3. ~~Nikkud~~ **Resolved by v244** — joined in from `content/nikud.json`
   at data-prep time, no separate vocalization pass needed.
4. **`clarification` field** — **shipped from day one**, as a Rashi-style
   expandable panel (`bicCommBar`/`bicToggleComm`), per explicit user
   request that it read the same way as the Torah's Rashi/Or HaChaim
   buttons.
5. **Where it slots into the pace wizard** — **Settings only for this
   first build**, not the first-run wizard (`CK_PACE_UI`/`renderChokPace`)
   - a segmented control (Rambam / Ben Ish Chai) plus a year picker when
   Ben Ish Chai is selected. The wizard's Halacha step still only offers
   Rambam; its "coming soon" copy was updated to point at Settings instead
   of promising a future wizard option, since extending the 3-step wizard
   itself was left out of scope for this pass.
6. **Extra metadata** (`glossary.json`, `ctxgloss.json`,
   `sefaria_refs.json`, `topics.json`) — **left for later**, not wired in.
   None of it blocks the core daily-reading flow; a "view on Sefaria" link
   from `sefaria_refs.json` is the most likely first candidate if this
   gets revisited.

## What was actually built

- `data/chok-benishchai-index.json` + `data/chok-benishchai/<year1|year2>/
  <unit-slug>.json` (98 unit files, ~6.2MB) - generated by a one-time
  data-prep script (not checked in) that joined `content/nikud.json`'s
  vocalized text onto each halacha, evenly split each unit's halachot
  across its 6 days (remainder front-loaded), and built the canonical-name
  → unit-slug map for combined units (Behar+Bechukotai etc.).
- `S.halachaWork` ('rambam' default | 'benishchai') and `S.bicYear`
  ('year1' default | 'year2') in Settings, under the same "קֶצֶב לִמּוּד"
  group as the existing Rambam-track picker.
- The Halacha section in the daily reader sources from either Rambam
  (unchanged) or the matching Ben Ish Chai unit for that week/day,
  depending on `S.halachaWork` - see `chokSectionsFor()`'s halacha branch.
- Verified with Playwright: normal week (grouped chapter-range source
  line, e.g. "בֶּן אִישׁ חַי · שָׁנָה א׳ · כי תבוא · הֲלָכָה א׳־ה׳"), a
  combined-unit week (Behar alone still resolves to the full
  Behar+Bechukotai content), a year-2 gap week (Halacha section absent,
  no crash), and the biur panel opening with the explanation text.

Known limitation carried over from the design: if the civil calendar
ever splits Behar/Bechukotai (or the other source-merged pairs) into two
separate Shabbatot in a given year, both of that year's weeks will show
the *same* full combined content rather than half each - the source data
doesn't distinguish where the shaar's own internal split would be. Not
expected to come up often since these pairs mostly stay combined.
