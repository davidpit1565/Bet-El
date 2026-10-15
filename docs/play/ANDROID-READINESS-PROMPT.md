# Prompt: make a Capacitor iOS-first app safe and ready for Google Play

Paste everything below the line into the Claude session of the OTHER app.

---

This app was built iOS-first (Capacitor + custom Swift plugins) and I now want to publish it on Google Play.
Audit the whole repo for Android readiness, fix what you find, and report in Hebrew (code, comments, commits stay English).

## Known bug class to hunt first (it already blanked another app of mine on Android)
1. `capacitor-native-bridge.js` (or any `core.registerPlugin('X')` for custom Swift-only plugins) must run ONLY when
   `Capacitor.getPlatform()==='ios'`, never just `isNativePlatform()` - on Android that is also true, the JS proxies
   get created, index.html believes a native UI exists (`!!Capacitor.Plugins.X` flags like NATIVE_TABBAR/NATIVE_HOME/
   NATIVE_TOPBAR), hides its own HTML screens, and the user sees an empty beige screen.
2. grep every `isNativePlatform()` and every `Capacitor.Plugins.<Name>` check: each one that assumes iOS must also check
   `getPlatform()==='ios'`. Android-valid plugins only: the ones in `capacitor.config.json > android.includePlugins`.
3. iOS-only network calls on Android (iTunes lookup / App Store update checks, apps.apple.com links, APNs push,
   Live Activities, widgets bridge, Spotlight, haptics bridge) must be skipped or replaced on Android.
4. Plugins that are missing on Android must fail silently (catch rejections, no uncaught exceptions at boot).
5. Android hardware/gesture Back: add `App.addListener('backButton', ...)` that closes overlays -> goes back one screen ->
   Home -> only then `App.exitApp()`. Otherwise Back closes the app from any screen.

## Full Play-readiness checklist
- Build: JDK 21, Gradle wrapper OK, `./gradlew bundleRelease` produces a signed AAB (keystore via gitignored
  `keystore.properties`; never commit keys). `versionCode` strictly increasing, `versionName` matches iOS.
- `targetSdk` meets Google's current requirement; `minSdk` sane; AndroidManifest permissions minimal and justified
  (INTERNET, location only if used, POST_NOTIFICATIONS for Android 13+); no leftover iOS-only permissions text.
- Edge-to-edge / safe areas: status bar + nav bar do not overlap content (check `env(safe-area-inset-*)` on Android 12-15).
- First launch must be usable immediately and online while any offline-data download runs in the background
  (never block the first render on a bulk download); show a small top indicator
  "Downloading for offline use - X / Y MB" with a progress bar; resume safely if interrupted.
- Every `fetch()` of bundled-or-remote data works from `https://localhost` (Android WebView origin) - CORS,
  mixed content, service worker and Cache Storage behavior verified.
- Firebase/Analytics: Android needs `google-services.json` (or the plugin excluded); make sure dev/test builds are
  detected correctly (`https://localhost` is a real shell on Android, not a dev host).
- Notifications channel + permission flow on Android 13+; exact-alarm permission only if truly needed.
- Share, open-external-link, copy, file/QR save: Android fallbacks exist (Web Share API / Capacitor Share / Browser).
- Fonts, RTL/LTR and every UI language render correctly in Android WebView (take screenshots, actually look).
- Privacy policy URL reachable; Data safety form answers match what the code really collects
  (Analytics, Firestore, push tokens, location).
- Store assets: 512x512 icon, 1024x500 feature graphic, phone screenshots per language, short (80) and full (4000)
  descriptions per language, release notes in `<xx-XX>` language tags.
- Personal developer accounts: closed test with 12+ testers opted-in for 14 continuous days is required before Production.

## How to verify without a device
Emulate Android in Playwright: `addInitScript` defining `window.androidBridge={postMessage(){...reject 'not implemented'...}}`
makes Capacitor report `getPlatform()==='android'`; then check the root class list has no `has-native-*` flags, the
home screen renders, no uncaught errors other than expected "plugin not implemented", and take screenshots.
Intercept `https://<user>.github.io/<repo>/**` with `page.route` if data is fetched remotely.

Deliver: a list of every problem found (severity), the fixes committed on a branch, and a short Hebrew
"ready / not ready for Play" verdict with remaining manual steps.
