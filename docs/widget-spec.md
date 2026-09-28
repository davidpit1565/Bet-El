# iPhone Home Screen Widgets — Spec (v1)

## Scope
Native iOS home-screen widgets (WidgetKit) for the Bet-El app ("תמיד"),
added as a new Widget Extension target inside the existing Capacitor iOS
project (`ios/App/App.xcodeproj`).

**v1 excludes interactive buttons (App Intents)** - per explicit decision,
that's a possible v2 addition. v1 is read-only, auto-refreshing content.

## Sizes
All three system sizes: Small, Medium, Large (same three widget kinds,
each with progressively more content - see "Content per size" below).

## Content
Three pieces of content, combined per size:

1. **תהילים היומי (Tehillim Yomi)** - today's psalm portion (chapter
   range), same daily division logic the app itself uses.
2. **תאריך עברי + זמני היום** - Hebrew date, plus the next relevant zman
   (or two: e.g. "עלות/נץ" in the morning, "שקיעה/צאת" in the evening) -
   not the full zmanim table, just what's relevant *right now*.
3. **התקדמות אישית (Streak)** - a **combined** consecutive-day streak
   across all the app's learning tracks, not just Tehillim (per explicit
   decision). The app currently has two *separate* streak counters
   (`betel_streak` for daily Tehillim, `betel_sm_streak` for Shnayim
   Mikra) and a Chok LeYisrael "done" array with no streak counter of
   its own, and no Musar streak/done tracking at all yet - so this is a
   **new small feature in the main app**, not just a widget-side read:
   a day counts toward the combined streak if the person did *any* of
   Tehillim/Chok LeYisrael/Musar/Shnayim Mikra that day, tracked as one
   new `betel_combined_streak` counter (updated from the existing mark-
   done call sites for each of those four features) and shown both in
   the app itself (a new streak chip, reusing the existing `.streak-
   chip` style) and shared to the widget via the App Group.

### Content per size
- **Small**: Hebrew date (short) + one zman line, OR the streak number
  with a flame/counter glyph - alternating isn't practical in a static
  render, so Small shows the Hebrew date + next zman (most universally
  useful at a glance), and the streak count as a small badge in the
  corner.
- **Medium**: Hebrew date + next zman (left) and today's Tehillim
  chapter range with a "פתח" tap target (right).
- **Large**: All three sections stacked: Hebrew date + 2 zmanim, today's
  Tehillim chapter range, and the streak with a short "X ימים ברצף"
  line.

Tapping anywhere on the widget deep-links into the app (opens directly
to the relevant screen - Tehillim reader for the chapter shown, or the
app's home screen as a fallback) via a `widgetURL`/App Intent link
using a custom URL scheme the main app already needs to register to
receive it (see "Deep linking" below).

## Design
Reuses the app's existing design system 1:1 (`design-system/
beit-el-design-system.css` as the reference, translated to SwiftUI):

- **Background**: **both** variants, per explicit decision - dark navy
  gradient (`#0b1226` → `#070b16`, matching `--bg-grad`) and the light
  parchment gradient (`#fbf5e6` → `#e7dcc2`, matching `[data-theme=
  "light"]`'s own `--bg-grad`). Which one shows follows the app's own
  stored theme preference (`S.theme`, the same dark/light toggle already
  in Settings), not the iPhone's system-wide light/dark mode - so the
  widget matches whatever look the person chose inside the app itself.
  This means `S.theme` needs to be included in the shared App Group
  blob (see "Data sharing" below) alongside the streak/position data,
  and the widget's views need a light/dark color-token pair (mirroring
  the CSS custom properties) rather than relying on SwiftUI's automatic
  `colorScheme` environment value.
- **Accent**: the gold gradient/color (`--gold: #d4af5f`, `--gold-bright:
  #f3e3af`) for numerals, the streak flame, and dividers.
- **Typography**: `Noto Serif Hebrew` for the Hebrew date and Tehillim
  reference (sacred/reading text), `Heebo` for smaller UI labels - both
  already used as Google Fonts in the app; for the widget they need to
  be bundled as local font files (WidgetKit extensions can't load remote
  webfonts), added to the widget extension's target and declared in its
  `Info.plist`.
- **Ornamentation**: a subtle version of the app's gold divider/star
  motif between sections, kept minimal so it doesn't fight WidgetKit's
  own corner-radius/padding chrome.

## Dynamic Timeline (auto-refresh)
A `TimelineProvider` supplies several `TimelineEntry` points ahead of
time so the widget updates without the app running:

- **Daily boundary**: one entry generated for "today" at local midnight
  (new Hebrew date, new Tehillim portion, streak re-evaluated).
- **Zmanim-relevant refresh points**: additional entries at the zmanim
  that actually change what's displayed (e.g. alot hashachar, netz,
  chatzot, shkia, tzeit) computed for the day ahead, so the "next zman"
  line advances through the day without the OS needing to guess.
- **Reload policy**: `.after(nextBoundaryDate)` chained through the
  entries above, capped at a `.atEnd` refresh at the last entry (system
  midnight) - WidgetKit still applies its own OS-level budget on top of
  this (typically a handful of reloads/day per widget), so this is a
  best-effort schedule, not a guarantee of every entry firing exactly on
  time.

## Data sharing (App Group)
The widget extension can't reach the main app's JS/localStorage runtime
directly, so:

1. Add an **App Group** capability, `group.com.beitel.tehilim` (matching
   the app's real bundle ID, `com.beitel.tehilim`, already found in
   `ios/App/App.xcodeproj/project.pbxproj` - no need to look this up
   separately), to both the main app target and the new widget
   extension target.
2. The main app (JS side, via a small native Capacitor plugin call, or
   directly in `AppDelegate.swift` on specific lifecycle events) writes
   a small shared JSON blob into the App Group's shared UserDefaults (or
   a shared file in the App Group container) whenever the relevant data
   changes: today's streak count, last-read Tehillim position.
3. The widget's `TimelineProvider` reads that shared blob at each
   timeline refresh; the Hebrew date/zmanim/Tehillim-portion themselves
   are computed independently in Swift (a small port of the app's own
   date/zmanim math, not fetched from the JS side), since those are
   pure functions of today's date + location and don't need live app
   state.
4. Location for zmanim: reads the same stored lat/lon the main app
   already persists (via the App Group), falling back to the same
   Antwerp default the app itself uses if none is set yet.

## Deep linking
- The main app needs a custom URL scheme (e.g. `betel://tehillim/<day>`,
  `betel://siddur/zmanim`) registered in `Info.plist` if it doesn't
  already have one, and a minimal handler in `AppDelegate.swift`/
  `SceneDelegate.swift` that maps the incoming URL to the right in-app
  screen (calling the existing JS `go(tab)`/`openPrayer(...)` functions
  via the Capacitor bridge).
- Each widget entry sets `widgetURL(...)` to the right deep link for
  what it's currently showing.

## What gets hand-written vs. what needs Xcode
This session has no Xcode/macOS, so every file below is written by hand
as plain text/code, not compiled or run here. All of it needs a first
real build in Xcode before it can be trusted:

- New target in `ios/App/App.xcodeproj/project.pbxproj` (a WidgetKit
  Extension target) - this is the highest-risk hand-edit, since Xcode
  project files are easy to get subtly wrong by hand and there's no way
  to validate the file here beyond checking it's well-formed enough for
  Xcode to open without immediately erroring.
- `ios/App/BetElWidget/` (or similar) - the extension's own folder:
  - `BetElWidgetBundle.swift` (the `@main` entry point)
  - `BetElWidget.swift` (the actual `Widget` + views for all 3 sizes)
  - `Provider.swift` (the `TimelineProvider`)
  - `SharedData.swift` (App Group read/write helpers, shared with the
    main app target)
  - `Info.plist` for the extension
  - `BetElWidget.entitlements` (App Group capability)
- Updated `ios/App/App/App.entitlements` (or a new one) adding the same
  App Group.
- Bundled font files for the extension (copied from `fonts/` or
  re-exported).
- A small `AppDelegate.swift`/native-plugin addition for (a) writing the
  shared streak/position data on the relevant app lifecycle events, and
  (b) the deep-link URL handler.

**None of this touches `www/`, `data/`, or the web app itself** - it's
purely additive inside `ios/`, so `npm run cap:sync` (which only copies
web assets and syncs Capacitor's own config) won't discover or affect
it either way; it needs to be committed to git alongside the rest of
`ios/App`.

## Timeline for this week
1. This spec (today) - confirm before writing code.
2. Write all the Swift/plist/entitlements files + the pbxproj target
   addition (1-2 sessions of work, given the size).
3. Hand off to you to open in Xcode, add the target's build settings
   Xcode itself needs to fill in (signing team, bundle identifiers -
   these can't be guessed correctly from here), and do the first real
   build.
4. You report back any compile errors; iterate from there.
5. Once it builds and the widget shows real data on a device/simulator,
   this becomes part of the next app-store update build.

## Decisions confirmed (no longer open)
- **Interactivity**: Timeline-only in v1, no App Intents buttons.
- **Bundle ID / App Group**: `com.beitel.tehilim` → `group.com.
  beitel.tehilim` (read directly from `project.pbxproj`, not asked).
- **Streak scope**: combined across Tehillim/Chok LeYisrael/Musar/
  Shnayim Mikra (a new small main-app feature, not just a widget read).
- **Color scheme**: both dark and light variants, following the app's
  own stored theme setting (not the system-wide iOS appearance).

## Still open
- Apple Developer **signing team ID** - Xcode fills this in once you
  open the project and select your team under Signing & Capabilities;
  can't be set correctly from here.
