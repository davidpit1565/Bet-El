# Ben Ish Chai — integration analysis & plan (not yet built)

Source: a standalone reference app the user uploaded
(`ben-ish-chai-app-v242.zip`, ~4.5MB) containing per-parasha Ben Ish
Chai halachot data. This document analyzes that data against Bet-El's
existing Chok LeYisrael architecture and proposes how a "Ben Ish Chai"
track would be added, matching the already-planned mention in
`CLAUDE.md`'s Halacha pace question ("בְּקָרוֹב: מַסְלוּל בֶּן אִישׁ חַי
יִצְטָרֵף כְּאוֹפְּצְיָה נוֹסֶפֶת").

Nothing has been built yet — this is the analysis + design the user
asked for before starting.

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

## Open questions before building anything

1. **Only year1 for now, or wait for year2?** No year2 data exists yet.
   If the app should offer both years as parallel pace choices (like
   Rambam's 1-year/3-year toggle), that has to wait; shipping year1
   alone as a first Ben Ish Chai option is the only thing buildable
   today.
2. **The 6 missing parshiot** — ship with a graceful gap, or hold off
   until the content backfills?
3. **Nikkud** — worth running through Dicta's Nakdan now (same
   pipeline as Pele Yoetz), or ship unvocalized first and add it later?
4. **`clarification` field** — include it from day one (needs new UI),
   or ship the raw halachot first and layer explanations in later?
5. **Where exactly it slots into the pace wizard** — replace Rambam
   entirely as a choice, or become a third Halacha option alongside the
   two existing Rambam tracks?

No code changes were made for this — this file is the analysis and
plan only, for the user to confirm before anything is built.
