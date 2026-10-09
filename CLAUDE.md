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

- **Study booklet (חוברת לימוד)** - its own name / brand everywhere it
  names itself (cover title, running header band, the TOC/back page pill,
  the rights lines, the PDF file name) is **"הַתָּמִיד"** - the app's
  confirmed name, as in support/privacy/terms.html (`BK_UI.brand` /
  `brandStam` "התמיד" / `backMade`); "בית אל" there was a placeholder. The
  Bet El verses in `BK_UI.ring` are scripture (unused on the cover now),
  not branding. Home card `homeBookletCard` →
  `openBooklet()` → `renderBookletHome()` (`TAB==='bookletHome'`, day
  picker + contents + print/PDF) → `renderBookletReader()`
  (`TAB==='bookletReader'`). Built strictly from the reader's own path:
  `chokSlotFor(date)` + `chokSectionsFor(key,day,hd)` over a real date
  (the reader's own single-work musar section is filtered out via `BK_SKIP`;
  the booklet instead prints ALL six works of `MUSAR_WORKS` as ONE plain
  "מוּסָר" subject of the day, right after Halacha where the reader puts
  Musar - `bkMusarSection`: each work read exactly as the reader reads it
  (`ckMusarIndexes` + `ckMusarSegs`), run on in sequence as one two-column
  flow, each work opened only by a small sub-heading line `.bk-ml` (name +
  fading hairline, body size, subordinate to the heading) - the
  owner's call, no header per book - at the same body size as the rest of
  the day: `.bk-cols` changes layout only, never text size; a Musar load
  failure sets
  `BK_MUSAR_FAIL` so the day still renders); nothing is resolved a second
  way. `bkBlocks(date)` is one
  block list rendered twice: a reflowing on-screen `.bk-sheet`, and
  JS-paginated **A5** (148x210mm, the printed booklet's real page - type is
  set for it, not shrunk from A4) `.bk-page` boxes in `#bkPrint` (`bkPaginate`) shared by
  `window.print()` (`@media print` shows only `#bkPrint`) and the PDF
  export (html2canvas at scale 3 + jsPDF `format:'a5'` per page - its
  `ignoreElements` leaves the other pages and the on-screen sheet out of each
  capture's document clone, or a 65-page booklet takes 10+ minutes instead
  of ~75s - lazy-loaded from cdnjs via
  `loadScriptOnce`). Real page boxes are what allow the per-page header band
  (parasha / medallion / day · subject). The Gemara is the real Vilna page
  image from shas.org's Daf PDF API, rendered to an `<img>` with PDF.js;
  shas.org has no CORS header, so the web build fetches the same-origin
  `/shas-daf/<masechta>/<daf>/<amud>` Vercel rewrite (vercel.json) and
  native uses CapacitorHttp; any failure falls back to the citation line.
  Each fully-rendered amud gets a page of its own in print (`dafPage` in
  `bkPaginate`): the scan (margins auto-trimmed, white paper multiplied to
  the booklet ivory in `bkRenderPdfPage`) fills the body, only the header
  band sits above it, narrowed to the scan's width via `--bk-daf-w`; the
  Gemara section's title/divider are print-hidden (`dafSec`/`noPrint`
  blocks); no credit line on the scan pages - see the license note below.
  **The printed booklet is the whole Chok LeYisrael week** of the selected
  date, while the on-screen `.bk-sheet` still shows just that day:
  `bkWeekRows(date)` walks `CHOK_ROWS` (Sun-Thu, Leil Shishi, Fri), each
  row resolved for its own real date (Leil Shishi = Thursday's date, its
  `night` row; `bkSections(date,'night')` keeps only the tzeruf - the
  night's other subjects are Thursday's, already printed - its Hebrew date
  line shows Friday's, with "(בָּעֶרֶב)"); `bkWeekBlocks` concatenates
  `bkBlocks(date,{day,week:1,brk})` (each day after the first starts a
  page, no per-day Ben Ish Chai or license blocks); week-level
  `bkWeekReady`/`ensureBookletWeek`/`bkWeekDafs`/`ensureBkWeekDafs`/
  `bkWeekDafPending` gate the reader, print and PDF; the cover shows the
  full calendar week Sunday-Shabbat inclusive (`bkHebRange`; owner's call -
  even though printed days stop at Friday); TOC day subtitles are the day's Hebrew
  date. Ben Ish Chai closes the week once, per track via
  `bkBicKeys(slot,track)`, which for a content gap (year 2) falls back to
  `bicNearestAvailableKey()` exactly like the live reader, naming the
  parasha actually used under that year's title. The Halacha section's
  cartouche reads "רַמְבַּ״ם · <hilchot · perek>" (no separate source line;
  band/TOC label "רַמְבַּ״ם"). `booklet-audit.mjs` audits every row of the
  week (duplicate source lines are checked per day - a Tanya letter can
  span days).
  **Owner decision (2026-10): the printed booklet goes black & white**
  (weekly physical print cost) - every gold accent (double border,
  corner ornaments, cartouches, medallion/header band, text accents)
  becomes black/dark grey on white/off-white, same shapes and ornaments.
  **Hillulot (owner's "לְעִילּוּי נִשְׁמַת הַצַּדִּיקִים")** - every week's booklet
  shows, under each day's heading and before its first subject, that
  date's yahrzeits exactly as the app's calendar day card does: same data
  (`data/hillulot.json`, Nahar Shalom luach - names verbatim, never edited)
  and same resolver (`ensureHillulot`/`hillulotFor`, ported verbatim from
  main's 681474f/6dadfb7/456f273 - Adar leap-year lists, a missing 30th on
  the 29th). Nothing on a day without one; none for Leil Shishi (its Hebrew
  date is Friday's). `bkHillulotHtml` -> a framed `.bk-hill` block marked
  `head:1` (moves with the day/subject headings, keeps the header label);
  loaded with the week (`ensureBkHillulot`; `BK_HILL_FAIL` never blocks).
  NOTE: this branch has not merged main (326+ commits behind at the time):
  main restructured the home tiles and reuses `homeBookletCard` for its own
  published weekly-booklet PDF - merging needs those two features
  reconciled; until then the hillulot code here loads with plain fetch
  instead of main's cachedFetch/dataURL. When main is merged, keep main's
  copies of ensureHillulot/hillulotFor and drop this branch's duplicates.
  Friday closes with "שַׁבָּת שָׁלוֹם וּמְבוֹרָךְ!" (`bkWeekBlocks`; Shabbat
  has no pages). The enlarged opening words were dropped (owner: they came
  out inconsistent). A day never ends on a near-empty page: before each
  day break `pullBack` tries to fit a last page of <= `BK_PULL_LINES` (3)
  lines back onto the previous page set a little tighter (`.bk-tight`,
  then `.bk-tighter`), rejoining the paragraph cut between them; if it
  still doesn't fit, nothing changes.
  Built as a booklet-only mode (`BK_BW`, per-viewer
  `localStorage['betel_bk_bw']`, default on; a toggle button in the booklet
  reader): ONE colour function `bkMonoRGB` (warm hues 12-62deg only:
  accents -> near black/dark grey, l>=.86 paper/highlights -> neutral
  off-white) applied to (1) a generated copy of every `.bk-*`/`orn` CSS rule
  in source order under the ZERO-specificity `:where(.bk-bw)` prefix
  (`bkBwStyles`; copying under plain `.bk-bw` raised specificity and broke
  the cascade - BIC font sizes changed, the page count moved), and (2) the
  colours inside generated pages (`bkBwDom`: fill/stroke/stop-color/style
  attributes). Never a CSS filter (html2canvas ignores filters; print would
  rasterize). Daf scans and the QR are tinted to the mode's paper and
  cached per mode (`bkDafKey` '|bw' suffix, `bkQrKey`). The earlier weekly
  colour-rotation idea (gold/blue/pink/green/orange/purple) is dropped.
  Page order: cover, rights/contact, the Rav's honour page (`bkRavHtml`,
  `BK_RAV` - owner's text verbatim), dedication, contents, days, Ben Ish
  Chai, back, blank (`startNo` counts the front pages actually built).
  Keep-with-text rule (`bkPaginate`): at any page break inside a section,
  if that section's heading run is on this page with fewer than
  `BK_MIN_LINES` (6) lines of text below it (over however many blocks -
  `bkLinesAfter`), the heading(s) and everything after move to the next
  page. A chapter heading alone (`sub`: Tehillim/Mishnah/Rambam perek)
  needs only `BK_SUB_MIN_LINES` (2) - text runs on across chapters rather
  than leaving a page foot empty (owner's Tehillim complaint).
  Header band title: no shadow, highlight or glow at all (owner) -
  `ornTitleSvg(...,soft)`; the band's old centre glow rendered on some pages
  only, so it is gone. Dedication slots take one or more names; the
  surrounding wording switches singular/plural by count (`dedBlessPl`,
  `dedMeritPl`, `dedTnzbhPl`).
  `bkBuildPrint` wraps the week in front/back matter built from the same
  frame/strip/medallion, except the cover and dedication, which are
  full-page ornament compositions modelled on the owner's reference booklet
  ("האוצר", נהר שלום): one inline SVG per page (`ornCoverSvg` /
  `ornDedicationSvg`, from a small kit - `ornSpiral`, `ornEmboss` (every
  motif drawn as highlight + shadow + mid tone for an embossed look),
  scroll wallpaper / scroll-column `<pattern>`s, rope-twist lobes
  `ornRopeV`/`ornRopeRing`, `ornCrest`, `ornLaceArc`, `ornPlaque`) under
  absolutely placed HTML (`.bk-ol`) for all text, the logo and the QR. Every
  root `<svg>` needs `xmlns` or html2canvas can't draw it; text stays HTML
  (html2canvas can't use web fonts inside an SVG image), including the
  medallion's ring text (`ornRingText`, one rotated span per letter, the
  Bet El verses Bereshit 28:17/19 in `BK_UI.ring`, no longer printed on the
  cover). Cover (the owner's approved direction, from a Canva reference:
  THE FRAME ONLY - no logo, no medallion, nothing in the centre):
  `ornCoverSvg` = ivory paper, a double gold border (heavy outer line, thin
  inner line that stops at each corner in a bead finial - the ornament IS
  the corner, as in the reference) and an openwork acanthus corner
  (`ornFrameCorner`, built from `ornLeaf` - lobed leaves generated along a
  curve - plus thin scrolls: a fleur-de-lis on the corner point, a slim
  leaf curling out along each arm, an inner C-scroll, a bud pointing into
  the page; mirrored to all four corners at scale 1.3) - matched
  side-by-side against the owner's approved Canva reference
  (scratchpad canva-cover-ornament-v2.png, minus its medallion), with the title
  "בית אל" (`BK_UI.brandStam`, no nikud) standing in the open centre in the
  scribal Culmus Stam Ashkenaz face (fonts/, GPL + font exception, like
  Taamey Frank) with a gold metallic fill - `ornTitleSvg`, the font
  embedded as a data: URL by `ensureBkFont()` (also a document FontFace
  for print; print/PDF wait for it via `bkMatterPending`); then
  "חוֹבֶרֶת לִמּוּד", the parasha, dates, QR - supporting lines in Taamey
  Frank Bold. The dedication and back pages were NOT changed with it - ask
  the owner before restyling them to match.
  Dedication (after the owner's memorial-page reference "לְזִכְרוֹן עוֹלָם
  בְּהֵיכַל ה׳"): a top band rising to a scroll crest, a hanging oil lamp
  (`ornLamp`) between the two halves of the header (`BK_UI.dedHdr`), and
  the memorial and the blessing each in its own double-line frame with
  curled corner volutes (`ornVoluteFrame`), holding the wording from
  `BK_UI` dedLead/dedMerit/dedTnzbh/dedBless/dedAmen/dedFoot around the
  names in `BK_DEDICATION` - the owner's confirmed names, verbatim, never
  "fix" them; empty = a blank line. And a
  back page (`bkBackHtml`, credits/distribution text + QR, the support
  contact block (`BK_UI.contactH`/`contact`, info@bet-el.be), plus - whenever
  the booklet carries a daf scan - the small-print legal block with
  `BK_SHAS_CREDIT` and the full `BK_HB_LICENSE`). The QR is the
  App Store link from `appQrSrc()` (shared with `appQrImage()`); QR and logo
  are preloaded as data: URLs (`bkImgData`/`ensureBkMatter`) so print and
  html2canvas never wait on a cross-origin image, and print/PDF wait for
  them like they wait for the daf (`bkPending`). After the dedication, a
  contents page (`bkTocHtml`): by day - each day, then its subjects with the
  page each starts on (`bkPaginate` records each day/subject heading's DOM
  node in `meta.toc`, or the first scan page for a print-hidden Gemara
  title, and resolves it to its final page's `data-no` - a heading carried
  to the next page moves with its node, so the number is exact) - then the
  Ben Ish Chai year 1/2 entries as placeholders ("בְּהֲכָנָה", no content
  or page yet). The contents page is a book's list, never a table grid
  (owner's call): per day a heading (name, parasha), then one dotted-leader
  line per subject with its page (`bkTocDays` groups `meta.toc`,
  `bkTocHtml` draws it). A long list sets in 2 columns (>30 lines) or 3 (>60,
  a whole week) - the owner's hard target is ONE page for a full week; a
  patched-copy mockup of all seven rows fits one page in 3 columns.
  Every row shares one fixed-width page-number column so all leaders end
  on one line; placeholder rows (Ben Ish Chai) show "—" there, with
  "בְּהֲכָנָה" once beside their heading (where a day shows its parasha). The
  Mishnah prints without its source line (it read as a Gemara citation);
  instead a "פֶּרֶק ב׳" sub-heading when the chapter changes and each mishnah
  its own paragraph under its own "מִשְׁנָה י׳" heading block (`.bk-mn`, a
  'sub' block so the paginator never strands it). Tanya, like the Zohar,
  is one two-column flow.
  Printed-booklet order (asserted by booklet-check): cover, the rights &
  contact page (page 2, the inside of the cover - `bkRightsHtml` /
  `ornRightsSvg`: after the reference booklet's own page 2, an arched gold
  panel, a ribbon with "כל הזכויות שמורות © התמיד" (no seal - the owner's
  call), then the distribution note and the contact block - ONLY the
  booklet's own approved `BK_UI` texts (backMade/backDist/contactH/contact),
  never invented claims), dedication, contents, the day's pages (Musar
  inside them), the back page, a closing blank (`bkBlankHtml`). Pages are
  numbered on from the cover (cover 1, rights 2, dedication 3, contents 4,
  first day page 5). Every day page (incl. the Gemara scan pages, where it
  narrows to the scan's width) opens with the running header band
  (`bkPageHtml` → `bkBandSvg`, after the reference's own running head): a
  light band between two small embossed lace ribbons (`ornLaceRibbon`), a
  filigree crest above and below the gold Stam "בית אל" in its centre
  (`ornTitleSvg`), the parasha on one side and day · subject
  (`.bk-ph-lbl`, relabelled by the paginator) on the other. The TOC and
  back page keep the plain strip + small "✦ בֵּית אֵל ✦" pill header
  (`bkMatterPage`). Torah/Neviim/Ketuvim print one verse
  per line (`.bk-vline`, number in a hanging column - the owner's pick over
  run-on verses); Tehillim/Rambam/Mishnah still run on. Halacha (Rambam)
  and Zohar print in two columns (`.bk-cols`, CSS columns inside `.bk-page`
  only; the Zohar is ONE flow with block paragraphs so it runs down the
  columns continuously; no rule between the columns - the owner wants the
  gap alone).
  `BK_SHAS_CREDIT` and `BK_HB_LICENSE` are license requirements - never
  drop them. In print they appear once, together, on the back page (owner's
  decision, replacing a per-scan credit line); on screen the reader keeps
  them beside each scan / at the end of the day (`noPrint` blocks).
  Interior richness (after the reference booklet's own reading pages):
  each subject title is a framed cartouche on tapered gold rules
  (`.bk-page .bk-sec-t` + ::before/::after; the "בֵּיאוּר" divider `.bk-bdiv`
  matches), a filigree crest over each day title (`.bk-day-crest`), and a
  faint paper vignette on `.bk-page`. The running header's labels are
  optically centred on the band's light strip (row = strip, labels nudged
  down for nikud, title nudged up) - the owner's "too high" fix.
  Verse/halacha markers (`.bk-vn`) are bold gold numerals at .82em on the
  text baseline, not raised superscripts. `ckCommFor(id,key)` /
  `ckTargumFor(...,key)` take an optional explicit parasha key for exactly
  this kind of not-the-reader's-week rendering. **Ben Ish Chai** closes the
  booklet (`bkBicBlocks`, after the day): a part opening a new page
  ("בֶּן אִישׁ חַי" + parasha), then year 1 and year 2 as its subjects - the
  week's parasha per track (`ckKeysOf(slot.key)`, de-duped by unit; a
  track with no unit for the week is left out) read exactly as the
  standalone reader reads it: `bicFlatItems` (intro, then every halacha
  in source order with its own number `h.chapter`) and `bicI18nItem` for
  a translation. Print layout: halacha text on top (`.bk-bic-h`, full
  width), biur below the "בֵּיאוּר" divider (`.bk-bic-b`, two columns) - and
  per the owner, the two zones are ALWAYS in sync: every page shows the same
  halachot (or the same part of one) in both. `bkPaginateBic` builds pages
  from units (`bkBicUnits`: one halacha's text + its whole biur; the intro
  is text only under a "פְּתִיחָה" heading): whole units while both zones
  fit; else a matched piece - the largest fraction f (of `BK_BIC_STEPS`)
  with the first f of the text AND of the biur fitting together, the text
  cut snapped to a sentence end (`bkSnapCut`) and the biur recomputed to
  the same share; on a page already holding units a unit is cut only if
  >= `BK_BIC_MIN_FRAC` of it fits (and `BK_BIC_MIN_WORDS` of text), else it
  starts the next page. (The earlier design - two independently flowing
  streams - was rejected: pages came out nearly all biur or all halacha.)
  `bkTidy` closes the source's stray spaces before punctuation. The on-screen sheet keeps the
  simple halacha-then-biur sequence (`bkBicBlocks`, all noPrint). Loaded with the day
  (`ensureBkBic`/`bkBicReady`; `BK_BIC_FAIL` never blocks the day). The
  TOC lists the two years with real pages (the "בְּהֲכָנָה" placeholders
  remain only when no Ben Ish Chai content was built). Vayera = ~42 A5
  pages of it.
  Owner decisions (settled, don't re-ask): Rashi on Yehoshua / Melachim
  stays absent (the Sefaria edition is CC-BY; not added); the Gemara stays
  on the world Daf Yomi cycle (not the parasha-linked Chok LeYisrael
  gemara). Scope so far: ONE day;
  still to build: the Sun-Thu/Leil Shishi/Fri week loop, and the Motzei
  Shabbat `checkBookletNotification()`. Check with
  `node scripts/booklet-check.mjs [YYYY-MM-DD] [outDir]` (fakes the date,
  emulates the Vercel rewrite, saves screen/print/PDF output), and
  `node scripts/booklet-audit.mjs [YYYY-MM-DD] [out.json]` (content audit:
  every segment the reader's own resolvers give for the day - verses,
  Targum, each commentary, Mishnah, Rambam, Zohar, Tanya, all Musar works -
  must appear word for word in the printed pages; plus stranded headings,
  overflow, duplicate source lines, back-page license). Both exit non-zero
  on any finding.

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
- **Nevi'im/Ketuvim refs that cross a chapter** ("Proverbs 3:34-4:3", 91 of
  them in the schedule, every one crossing exactly one boundary) carry
  their own chapter split: the last `v2` segments are chapter `c2`, so
  `c1` ends at `v1+(segments-v2)-1` (`chokVerseSegs`). It used to take the
  length from the Haftarah data, which has no Ketuvim and isn't always
  loaded, so every verse after the first was renumbered and its Targum and
  commentary looked up one verse off. The original data prep had the same
  bug: those first-chapter verses had no commentary at all until
  `scripts/fill-cross-chapter-comm.py` filled them (136 verses, from the
  same Sefaria editions, verified text-for-text first).
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
- **App Store QR code**: done - the app was approved and is live on the
  App Store (id6807186847) as of 2026-09-09. `appQrImage()` (index.html)
  now encodes `APP_STORE_URL` (`https://apps.apple.com/app/...`) instead
  of the PWA's own `location.href`.
