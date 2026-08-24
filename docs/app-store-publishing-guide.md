# Publishing to the App Store and Google Play — step-by-step

Status as of this writing: `ios/` and `android/` native Capacitor projects
both exist and are kept in sync via `npm run cap:sync` (runs `npx cap sync`
with no platform arg, syncing both). App icons and splash screens for both
platforms were generated from `icon-512.png` via `@capacitor/assets`
(`resources/icon.png` is the source), using the app's dark navy background
(`#080d19`) instead of the tool's white default. `privacy.html` at the repo
root is deployed by the existing GitHub Pages workflow alongside
`index.html`, so it's reachable at `<pages-url>/privacy.html` — needed as
the privacy policy URL both stores require.

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
   ("בית אל · לימוד יומי" or an ASCII variant App Store may require),
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
3. Tell Gradle about it — create `android/keystore.properties` (already
   covered by `android/.gitignore`'s generic ignores; add it explicitly if
   not, it must never be committed):
   ```
   storeFile=/absolute/path/to/beitel-release.keystore
   storePassword=<the password you set>
   keyAlias=beitel
   keyPassword=<the password you set>
   ```
   and reference it from `android/app/build.gradle`'s `signingConfigs` /
   `buildTypes.release` block (Capacitor's default `build.gradle` has a
   commented-out or placeholder signing config — wire it to read from
   `keystore.properties` the standard Capacitor/Android way; ask an agent
   to do this edit once you have the keystore file, since it's a small
   code change).
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

## Multiple apps under one developer account

Both an Apple Developer Program membership and a Google Play Console
account can host **any number of separate apps** — there's no per-account
limit relevant to a small personal project. Each new app just needs its own
unique bundle ID / package name and its own listing in App Store
Connect / Play Console; the $99/year and $25 one-time fees are per
*account*, not per app.
