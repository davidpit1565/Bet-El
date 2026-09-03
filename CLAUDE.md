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
- Musar also has its own home-screen entry point (`homeMusarCard` →
  `renderMusarList()`, `TAB==='musarList'`), separate from - and in
  addition to - the musar work-switcher already inside the Chok
  LeYisrael reader. It lists all 6 works, each on its own row with
  today's `ckMusarSourceLabel()` (with the book-name prefix stripped
  since the row's own title already shows it) and a "today" button
  (`openMusarYomi(work)` → `renderMusarYomiReader()`, `TAB==='musarYomi'`)
  that jumps straight to that work's reading for the current date. Unlike
  the Chok LeYisrael musar section (purely date-driven, no position to
  track beyond which work is open), this standalone reader also lets you
  browse anywhere in the book: `MUSAR_YOMI_START` is an explicit override
  order-index (`null` = follow today's date via `ckMusarIndexes`) stepped
  ±3 by the prev/next-day arrows, or jumped directly via a `<select>` of
  every gate/chapter/topic from `musarSections(work)` (the same
  head-grouping logic as `ckMusarSourceLabel`, run over the work's whole
  `order` instead of just today's 3 indices) - mirroring the Ben Ish Chai
  reader's parasha picker, since browsing to an arbitrary section doesn't
  need to fetch the same "3 units" block set date-navigation always has
  ready, so it ensures its own block(s) before rendering.
- Ben Ish Chai is its **own standalone section** - a home-screen card
  (`homeBicCard`) opening three screens: `renderBicHome()`
  (`TAB==='bicHome'`, "this week's" parasha + year1/year2 progress cards),
  `renderBicParshiot()` (`TAB==='bicParshiot'`, a flat list of every
  parasha for a picked track), and `renderBicReader()`
  (`TAB==='bicReader'`, opened via `openBicReader(track,parashaKey,pos)`).
  Independent of Chok LeYisrael and not one of the Halacha options there
  (it was, briefly, during development - Rambam is Chok LeYisrael's only
  Halacha source again; `halachaChoice()`/`setHalachaChoice()`/
  `halachaChoiceLabel()` are back to a plain 2-way Rambam 3yr/1yr toggle).
  This structure (a this-week screen with two per-track progress cards, a
  flat all-parshiot list, and a flat one-halacha-at-a-time reader with its
  own per-halacha completion tracking) mirrors the original standalone Ben
  Ish Chai app this section is modeled on, rather than reusing Chok
  LeYisrael's day-based reader shape - deliberately, since the original
  app never split a parasha's halachot into study days at all; it's one
  flat, sequentially-numbered list per parasha (intro first, if any, then
  every halacha in source order), paged one at a time with an "X out of
  N" counter. `bicFlatItems(track,parashaKey)` reconstructs that exact
  flat sequence by concatenating the data file's `days[][]` arrays back
  in order (0..5) after any `intro` - the day split is purely our own
  data-prep pacing device (see the comment above `ensureBicWeek`), not
  something the original app or its data ever had, so no separate "flat"
  data files were needed. `BIC_DONE` (persisted to
  `localStorage['betel_bic_done']`, keyed by `track/parashaKey` → array of
  done flat-positions) drives the "X מתוך N" progress bar and
  continue/start-learning button label on each home-screen track card.
  Like Torah (and unlike Rambam's pure date-driven cycle, see
  `ckRambamIndexes`), it's parasha-bound: each parasha's halachot are
  pre-split across 6 arbitrary buckets **at data-prep time** (evenly,
  remainder front-loaded - there's no printed-sheet convention to
  hand-curate from, unlike Torah's own verse boundaries) into
  `data/chok-benishchai/<year1|year2>/<unit-slug>.json`, indexed by
  `data/chok-benishchai-index.json`'s `parshiot` array (ordered, per track)
  and `unitOf` map (canonical parasha name → unit slug - some units cover
  two canonical parshiot at once, e.g. Behar+Bechukotai, regardless of
  whether the calendar combines them that year, so `bicUnitsFor`/lookups
  de-dupe by unit slug rather than assuming one unit per canonical key).
  `S.bicYear` picks year1/year2 on the home screen;
  `bicNearestAvailableKey()` finds this week's parasha's nearest real
  content when year2's genuine content gaps (6 missing parshiot) put it
  in a hole, using Chok LeYisrael's own annual `CHOK.parshiot` order as
  the distance metric, since the Ben Ish Chai per-track list only
  contains parshiot that actually have content. `bicBody()`/`bicCommBar()`
  mirror `ramBody()`/`ckCommBar()`'s shape; the per-halacha plain-language
  explanation (`clarification`) shows in a Rashi-style expandable panel
  via `bicToggleComm()` - its own small function pair rather than folding
  into `ckCommFor()`/`ckToggleComm()`, since the data is already loaded
  inline (no async per-verse lookup) and there's only ever one explanation
  source, not several to pick between.
- Unlike Rambam and every Musar work, Ben Ish Chai's halacha body text and
  per-halacha biur are (gradually, by user request) being translated out of
  Hebrew-only. Each unit file can have sibling
  `data/chok-benishchai/<year1|year2>/<unit-slug>.<lang>.json` files (one
  per UI language other than Hebrew) with the identical `days[][]` shape -
  `ensureBicWeek()` fetches the sibling for the active language alongside
  the Hebrew base (a 404 is expected and cached as "no translation yet",
  not an error), and `bicI18nItem(track,unit,dayIdx,itemIdx)` looks up the
  translated item by the same indices `bicBody()` already uses, falling
  back to the Hebrew original per-item when absent. This was a large,
  incremental translation effort (~1,974 halachot × 4 languages); as of
  this writing all 51 year1 units and all 47 year2 units are translated
  into all 4 languages (en/fr/ru/ka), each following the same convention:
  halacha body paragraphs are phonetic transliteration only (like
  Tehillim/Prayers), while the `clarification` (biur/explanation +
  takeaways) is a genuine meaning-translation. The biur/`clarification` text itself has no nikud
  (unlike the halacha body, sourced from a vocalized original) - only
  Dicta-run text gets nikud, and the biur hasn't been run through it.
- The standalone Ben Ish Chai reader's sticky header is tall (year toggle
  + parasha picker + day nav on top of the back/title row), so everything
  below the back/title row is wrapped in its own `.bic-collapse` div that
  the shared scroll-direction listener (the `initNavScrollHide` IIFE,
  originally built for hiding the bottom nav) also collapses on scroll-down
  and reveals on scroll-up or after a pause - same interaction as
  Safari/YouTube's chrome, reusing the existing listener rather than adding
  a second one. Any other reader that grows a similarly tall sticky header
  can opt into the same behavior by giving its collapsible portion the
  `.bic-collapse` class - the listener queries for it by class, not by tab.
- Ben Ish Chai also gets its own daily local Notification
  (`checkBicNotification()`, mirroring `checkNotification()`'s Tehillim
  reminder) naming the current week's parasha, gated by the same
  `S.notifEnabled`/`S.notifTime` Settings toggle and its own
  once-per-day `betel_bic_notif_sent` flag - there's no separate opt-in
  for it specifically, enabling the general reminder toggle enables both.

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
- **Firebase push notifications**: real push infrastructure now exists
  (FCM Web Push) - a Settings toggle ("הוֹדָעוֹת עַל תֹּכֶן חָדָשׁ") requests
  permission, registers `firebase-messaging-sw.js`, and stores the FCM
  token in Firestore's `pushTokens` collection. Broadcast-to-everyone by
  design (no topic needed - Analytics is already linked, so a campaign
  from Firebase Console > Engage > Messaging targeted at the app itself
  reaches every registered token): https://console.firebase.google.com/project/bet-el-e6812/messaging
  **Whenever a new book, section, or other significant content is added
  to the app, remind the user that this is a good moment to send an
  announcement campaign** - don't send one yourself, just flag it.
- **Chok LeYisrael schedule explainer page**: built - `TAB==='chokExplainer'`
  (`renderChokExplainer()`), reachable from Chok LeYisrael's own topbar
  (info button), Settings, and the onboarding welcome screen. Uses the
  text from `docs/chok-leyisrael-explainer-draft.md` as confirmed by the
  user (still accurate as of the build) - if that content ever needs to
  change again, edit `CK_EXPLAINER_ITEMS` in index.html directly.
- **App Store QR code**: `shareQR()`/`appQrImage()` (index.html) generates
  a share image whose QR code currently encodes the PWA's own URL
  (`location.href`). Once the app is published on the App Store, update
  the QR target (and probably add an "also on the App Store" line) to
  point there instead - don't guess an App Store URL before it exists.
