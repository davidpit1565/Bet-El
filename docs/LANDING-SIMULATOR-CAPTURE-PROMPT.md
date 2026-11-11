# Prompt for the Mac terminal Claude: capture REAL simulator screens for the landing page

Goal: replace the web-build screenshots used by `landing/` with real iOS Simulator captures of the current app
(native Liquid Glass look), all from ONE device so the status bar / Dynamic Island / safe areas are identical.

Rules
- Build the app from `main` (Debug, iOS 26 simulator, iPhone 17 Pro or the newest Pro model), Hebrew UI first.
- Simulator status bar: `xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4`
- Light mode, Jerusalem location, a fixed date (e.g. a regular weekday, not a holiday).
- Capture with `xcrun simctl io booted screenshot --type=png <file>` at native resolution, one PNG per screen.
- Do NOT edit the app or commit app code. Save PNGs to `design/landing/sim/he/` named as below and open a PR with only those files.

Screens (Hebrew): 01-home, 02-home-scrolled, 03-daily-tehillim, 04-daily-finished, 05-calendar, 06-calendar-day,
07-library, 08-siddur, 09-compass, 10-tefillin-mirror (use the avatar photo / a still, no real face), 11-settings.
Then repeat 01-home for en, fr, ru, ka (`design/landing/sim/<lang>/01-home.png`).

Never print or commit signing keys, ASC credentials or team ids.
