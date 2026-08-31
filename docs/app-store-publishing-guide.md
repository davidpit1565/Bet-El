# Publishing to the App Store and Google Play — step-by-step

Status as of this writing: `ios/` and `android/` native Capacitor projects
both exist and are kept in sync via `npm run cap:sync` (runs `npx cap sync`
with no platform arg, syncing both). App icons and splash screens for both
platforms were generated from `icon-512.png` via `@capacitor/assets`
(`resources/icon.png` is the source), using the app's dark navy background
(`#080d19`) instead of the tool's white default. `privacy.html` and
`terms.html` at the repo root are deployed by the existing GitHub Pages
workflow alongside `index.html`, so they're reachable at
`<pages-url>/privacy.html` and `<pages-url>/terms.html` — the privacy
policy URL both stores require, and a Terms of Service URL for Google
Play's optional field / an in-app link to a custom EULA if Apple ever
asks for one. Both pages are self-contained (a small inline language
switcher, all 5 app languages' text embedded directly, defaulting to the
visitor's browser language) rather than separate per-language files -
also linked from Settings → "מִשְׁפָּטִי" inside the app itself.

This doc is the reference for what's left, which is almost entirely account
setup + signing/build steps only the app owner (not an agent) can do, since
they require a paid developer account and (for iOS) a Mac.

## iOS / App Store Connect

1. Enroll: https://developer.apple.com/programs/enroll/ ($99/year, requires
   a Mac — or a cloud Mac rental like MacinCloud if none is available).
2. Open `ios/App/App.xcworkspace` in Xcode (not the `.xcodeproj`).
3. In the App target's Signing & Capabilities tab: pick your Apple
   Developer Team. Bundle identifier is already set to `com.beitel.tehilim`
   (`capacitor.config.json`'s `appId`) — must match what you register in
   App Store Connect.
4. Create the app record in App Store Connect
   (https://appstoreconnect.apple.com) with that same bundle ID, app name
   ("תָּמִיד" or an ASCII variant App Store may require),
   primary category, and the `privacy.html` URL as the Privacy Policy URL.
5. Bump the version/build number (Xcode target → General tab, or directly
   in `ios/App/App.xcodeproj/project.pbxproj`'s `MARKETING_VERSION`/
   `CURRENT_PROJECT_VERSION`) before each submission — App Store rejects a
   re-upload of an already-used build number.
6. `Product → Archive` in Xcode (requires a physical or "Any iOS Device"
   target, not the simulator) → once archived, `Distribute App → App Store
   Connect → Upload`.
7. In App Store Connect: attach the uploaded build to a new app version,
   fill in screenshots (per required device size — Xcode's Simulator can
   capture these: `Cmd+S` on a running simulator), description, keywords,
   support URL, then submit for review.

Every subsequent update repeats steps 5–7 only (bump version, archive,
upload, attach to a new "version" in App Store Connect, submit).

## Android / Google Play Console

1. Register (one-time): https://play.google.com/console/about/ ($25).
2. Generate a signing key (do this once; **back this file up somewhere
   safe outside the repo — losing it means you can never update the app
   under the same listing again**):
   ```
   keytool -genkeypair -v -keystore beitel-release.keystore \
     -alias beitel -keyalg RSA -keysize 2048 -validity 10000
   ```
3. Tell Gradle about it — create `android/keystore.properties` (git-ignored,
   never commit it):
   ```
   storeFile=/absolute/path/to/beitel-release.keystore
   storePassword=<the password you set>
   keyAlias=beitel
   keyPassword=<the password you set>
   ```
   `android/app/build.gradle` already reads this file and wires it into the
   release `signingConfig` automatically when it's present — no further
   code change needed, just drop the file next to `android/app/` on
   whatever machine builds the release AAB.
4. Bump `versionCode` (integer, must increase every release) and
   `versionName` (the human-readable string) in `android/app/build.gradle`.
5. Build the signed release bundle:
   ```
   cd android && ./gradlew bundleRelease
   ```
   Output: `android/app/build/outputs/bundle/release/app-release.aab`.
6. In Play Console: create the app, fill in the store listing
   (description, screenshots — an Android emulator or a real device
   screen recording works), content rating questionnaire, and the
   `privacy.html` URL as the Privacy Policy.
7. Upload the `.aab` under a new release (start with the "Internal
   testing" or "Closed testing" track before "Production" — Google
   requires at least one testing track before your first production
   release on a new account).

Every subsequent update repeats steps 4–5 (bump version, rebuild) and 7
(upload the new `.aab` under a new release).

## App Privacy (App Store Connect) / Data Safety (Play Console) answers

Both stores make you fill in a data-collection questionnaire during
submission. Since the app collects nothing and sends nothing to any server
of ours, the honest answer to nearly every question is "no data collected":

- Apple's "App Privacy" section: select **"Data Not Collected"**. This is
  accurate — `localStorage` never leaves the device, and Google Fonts /
  the QR-code share service only see what any font/CDN request or a
  public share link already implies, not anything the App Store's
  category options are asking about.
- Google Play's "Data Safety" form: answer **"No"** to "Does your app
  collect or share any of the required user data types?".
- Encryption/export compliance (iOS): already answered by
  `ITSAppUsesNonExemptEncryption = false` in `Info.plist`, so Xcode/App
  Store Connect won't prompt for it on each upload.
- Content rating questionnaire (both stores): no user-generated content,
  no ads, no in-app purchases, no violence/gambling — this is religious
  study content, so it qualifies for the lowest content-rating tier
  ("4+"/"Everyone") on both stores.

## Reminder notification: wired, but still needs a real-device check

Settings' daily-reminder toggle now routes through `@capacitor/local-
notifications` on the native iOS/Android app shells (`notifReady()`/
`fireNotif()` in index.html), not just the plain Web Notification API used
by the PWA/browser install. Since this app has no JS bundler, the plugin
is loaded as a vendored UMD build (`capacitor-core.js` +
`capacitor-local-notifications.js`, plain `<script>` tags, copied straight
from `node_modules/*/dist` — re-copy them if either package is upgraded)
rather than `import`ed.

This has only been verified in a headless browser (the web fallback path
fires without errors). It has **not** been verified on a real device yet —
do that before submitting:
- Android 13+: confirm the app actually prompts for the `POST_NOTIFICATIONS`
  runtime permission when the Settings toggle is turned on, and that a
  reminder still fires the next day when the app isn't open.
- iOS: confirm the same permission prompt and next-day firing.

If it doesn't fire correctly, the fix is inside `notifLocalPlugin()`/
`fireNotif()` in index.html - not a blocker for getting the rest of the
store listing ready in the meantime.

## Multiple apps under one developer account

Both an Apple Developer Program membership and a Google Play Console
account can host **any number of separate apps** — there's no per-account
limit relevant to a small personal project. Each new app just needs its own
unique bundle ID / package name and its own listing in App Store
Connect / Play Console; the $99/year and $25 one-time fees are per
*account*, not per app.
