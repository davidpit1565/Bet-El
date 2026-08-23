# Working in this repo

## Language
The user writes in Hebrew. Answer and summarize in Hebrew (עברית) in chat —
not English. Code, comments, commit messages, and PR titles/descriptions stay
in English as usual.

## Architecture essentials
- Everything lives in one file, `index.html` (~5400+ lines): a giant classic
  `<script>` wrapped in a single top-level IIFE `(function(){ ... })();`.
  Nothing inside is reachable from outside except the handful explicitly
  exported near the end via `window.x = x;` (currently: `go`,
  `celebrateMilestone`, `ckMilestoneCheck`, `openPrayer`, `sharePrayer`,
  `shareQR`). This means Playwright's `page.evaluate()` **cannot call any
  other internal function or read any other internal variable** — testing
  must click real DOM elements (`document.getElementById(...).click()`,
  `document.querySelector(...)`) or use the exposed `window.go(tab)`.
- Data lives in static JSON under `data/`, fetched lazily via `ensureX()`
  loaders (never at boot). Every loader must reset its own load-promise
  variable to `null` in its `.catch()` so a transient fetch failure doesn't
  permanently poison that feature for the rest of the session:
  `.catch(e=>{ xLoadPromise=null; throw e; })`.
- The Musar system (`MUSAR_WORKS`, `MUSAR_UI`, `ckMusarSourceLabel`) is
  designed to make adding a new work mostly declarative: add `{key:'x'}` to
  `MUSAR_WORKS` and an `x` entry to every language block of `MUSAR_UI`
  (work name + `musarDesc`), and the pace-question wizard, the reader's
  work-switcher, and the Settings dropdown all pick it up automatically
  (they all filter/map over `MUSAR_WORKS` + `MCYC[key]`). Only extra code
  needed is a `gateName` branch in `ckMusarSourceLabel()` if the work's
  units are named (like Reshit Chokhmah's gates or Pele Yoetz's 391
  topics) rather than numbered - see `ckPeleYoetzTopicName()` for the
  pattern (a large per-language name table lives inside
  `data/chok-musar-cycles.json` itself, not inline in index.html, since
  that file is already lazy-loaded before any musar content renders).
- Every musar work runs at the same fixed pace, `ckMusarTrack()` = 3
  units/day (not configurable per-work). Cycle length is computed
  automatically by `ckMusarDurationLabel()`.
- Ben Ish Chai (`S.halachaWork==='benishchai'`, alongside the default
  Rambam) is an alternate Halacha source, parasha-bound like Torah rather
  than date-driven like Rambam/Zohar/daf. Its per-parasha halachot are
  pre-split across the 6 study days **at data-prep time** (evenly, remainder
  front-loaded - there's no printed-sheet convention to hand-curate from,
  unlike Torah's own verse boundaries) into
  `data/chok-benishchai/<year1|year2>/<unit-slug>.json`, indexed by
  `data/chok-benishchai-index.json`'s `unitOf` map (canonical parasha name →
  unit slug - some units cover two canonical parshiot at once, e.g.
  Behar+Bechukotai, regardless of whether the calendar combines them that
  year). `ckBenishchaiLabel()`/`bicBody()`/`bicCommBar()` mirror
  `ckRambamLabel()`/`ramBody()`/`ckCommBar()`'s shape. The per-halacha
  plain-language explanation (`clarification`) shows in a Rashi-style
  expandable panel via `bicToggleComm()` - its own small function pair
  rather than folding into `ckCommFor()`/`ckToggleComm()`, since the data is
  already loaded inline (no async per-verse lookup) and there's only ever
  one explanation source, not several to pick between.
- Unlike Rambam and every Musar work, Ben Ish Chai's halacha body text and
  per-halacha biur are (gradually, by user request) being translated out of
  Hebrew-only. Each unit file can have sibling
  `data/chok-benishchai/<year1|year2>/<unit-slug>.<lang>.json` files (one
  per UI language other than Hebrew) with the identical `days[][]` shape -
  `ensureBicWeek()` fetches the sibling for the active language alongside
  the Hebrew base (a 404 is expected and cached as "no translation yet",
  not an error), and `bicI18nItem(track,unit,dayIdx,itemIdx)` looks up the
  translated item by the same indices `bicBody()` already uses, falling
  back to the Hebrew original per-item when absent. This is a large,
  incremental translation effort (~1,974 halachot × 4 languages) - most
  units have no translation file yet and render in Hebrew regardless of
  UI language, which is expected, not a bug.
- The Halacha "pace" is really one choice of 4 (Rambam 3yr/1yr, Ben Ish
  Chai year1/year2), even though it's stored across two settings fields
  for historical reasons (`S.halachaWork` plus either `S.rambamTrack` or
  `S.bicYear`). `halachaChoice()`/`setHalachaChoice()`/
  `halachaChoiceLabel()` present/set all 4 as one unit everywhere they
  appear (Settings' single `<select>`, the pace wizard's Halacha step,
  and an inline 4-button `.ck-track` row in the reader itself - the same
  shape as the Musar work-switcher already there). Any async data source
  gated behind a first render of one of these screens (e.g.
  `ensureBicIndex()` on the wizard) must guard its post-load re-render
  with `if(!BIC_INDEX)` or equivalent - an unguarded `.then(rerender)`
  re-fires on every render of that step and hangs the page in an
  infinite microtask loop the moment the data is already cached. The
  regression sweep's fresh-user wizard case (a second, unflagged browser
  context walking language → intro → Halacha step with a hard timeout)
  exists specifically to catch this again.

## Before every push (do all of these, in order)
1. `node --check` on the extracted main `<script>` block (find its real
   start/end by locating the *actual* matching `<script>`/`</script>` pair
   via a small Python scan for `<script([^>]*)>` without `src=` - naive
   text search for `<script>`/`</script>` gives mismatched counts because
   the huge inline script itself contains those substrings inside string
   literals).
2. `node scripts/check-blocking-resources.mjs` (also wired into `npm test`).
3. `npm run cap:sync` (regenerates `www/` and the iOS project from the
   current `index.html`/`sw.js`/`data/` - both are gitignored/regenerable,
   never hand-edit them).
4. Local server + full regression sweep:
   `npm run serve:local &` (backgrounded, port 8899; uses
   `ThreadingHTTPServer` - the plain single-threaded `http.server` module
   can stall under Playwright's concurrent requests), then
   `npm run test:sweep`. Exits non-zero and prints `====ERRORS====` with
   details on any thrown error or unexpected console error.
5. For anything visual, take real screenshots (Playwright) and actually
   look at them before claiming a fix works - a passing sweep only proves
   nothing *crashed*, not that it *looks* right.
6. `git fetch origin main && git merge origin/main --no-edit` before
   pushing - other sessions/PRs land on `main` fairly often; merge cleanly
   rather than force-pushing over them.

## Hard-won lessons (don't reintroduce these bugs)
- **No `backdrop-filter` stacking.** A past redesign applied
  `backdrop-filter: blur()+saturate()` to a dozen-plus selectors at once,
  which reliably crashed Chrome's renderer ("Aw, Snap!", error code 5) once
  enough of those elements rendered simultaneously. The current CSS has a
  comment at the top of the "Liquid Glass" block explaining this - read it
  before adding any new blur/glass effect, and keep new decorative effects
  to flat gradients/borders/shadows only.
- **`#app` has no forced `min-height`.** It used to have
  `min-height:100vh/100dvh`, which stretched short pages to fill the
  viewport and looked fine only because the old hero was tall enough to
  rarely notice. Don't re-add it - `body`'s own fixed background already
  covers the full viewport independently of `#app`'s height.
- **Grouped source-line labels must not repeat the invariant prefix.**
  When multiple consecutive units share a book/gate/chapter, group them
  and show the shared head once with a paragraph *range* (`ckRange`), not
  once per unit. And when a single reader session's book/work name is
  itself invariant across the whole line (true for every Musar work - one
  reader session is always one selected book), prefix that name exactly
  once, not per group.
- **Test true edge cases, not just the common path**: a day whose units
  cross a chapter/gate/topic boundary, and the cycle-length wraparound
  (index modulo the order length), both have exposed real bugs before -
  fake the date (`Date` override via `addInitScript`) to reach them rather
  than waiting for the real calendar.
- If a Playwright script hangs with clean system resources (`free -h`,
  `uptime`, no leftover `chrome-linux/chrome` processes), don't assume
  it's a real app bug from one flaky run - isolate that exact case alone
  with verbose diagnostics before concluding anything. Sequential
  back-to-back browser launches in one Node process are themselves a
  common source of sandbox flakiness unrelated to the app.

## Standing open items
- **Firebase push notifications**: there is currently no real push
  infrastructure (no FCM, no server-side send capability) - the existing
  "reminder" toggle in Settings is a local, per-device notification only.
  The user wants to add real push (e.g. to announce new content) via the
  Firebase console themselves, at their computer - don't build this
  without them present.
- **Chok LeYisrael schedule explainer page**: an in-app page/table
  explaining what's studied each day and in what order, in plain language
  for end users (not a technical/internal document, no jargon like
  "cycle"/"anchor", no justifying the design vs. the traditional printed
  Chok LeYisrael). Content has been drafted and iterated on with the user
  across several rounds; the latest agreed direction has one line per
  section (Torah/Nevi'im+Ketuvim/Tehillim/Mishnah/Gemara/Zohar/Halacha/
  Musar) stating its concrete daily unit (e.g. "one Gemara daf a day",
  "5 chapters a day on the monthly Tehillim division, or the day's fixed
  chapters on the weekly division"), a mature/adult tone, and the Musar
  line naming all 6 books without the word "classic". Placement in the
  app is not yet decided. The current agreed draft text is saved at
  `docs/chok-leyisrael-explainer-draft.md` - confirm with the user before
  building, since it may have evolved further.
