# פרומטים ל-Claude Code בטרמינל (על המק)

שלושה פרומטים, לפי הסדר. כל אחד עומד בפני עצמו. **אף פעם לא מדביקים בצ'אט או בגיט מפתחות / קובצי `.p8` / סיסמאות** – הם נשארים על המק בלבד.

---
## פרומט 1 – לראות את כל השינויים עכשיו
```
cd ~/Bet-El (the Bet-El repo ONLY, not halacha-yomit-ios).
1. git stash if there are local changes; git pull origin claude/additional-file-fas9ie; git stash pop. Never commit my local DEVELOPMENT_TEAM change.
2. npm run cap:sync, then build and install the "App" scheme of ios/App/App.xcworkspace on my connected iPhone (bundle id com.beitel.tehilim, existing Team and App Group group.com.beitel.tehilim, BetElWidget embedded and signed). Build number is 6. If anything fails to compile fix it minimally (keep the iOS 15 deployment target, use #available), commit and push to the same branch.
3. FIREBASE (project bet-el-e6812): fetch the CURRENT Firestore rules first (Firebase Rules REST API) and show me; add only `match /feedback/{id} { allow create: if request.resource.data.message is string && request.resource.data.message.size() <= 2000; allow read, update, delete: if false; }` if feedback is not allowed yet; deploy; verify a test write works and a client read is denied.
4. Check device logs for NativeSystem, NativeHome, NativeTopBar and BetElWidget errors/crashes; tell me if the widgets render in the gallery.
5. Report in Hebrew.
```

---
## פרומט 2 – צילומי מסך אמיתיים (סימולטור) + העלאה אוטומטית ל-App Store Connect
**לפני שמריצים (5 דקות, פעם אחת, רק אתה יכול):** App Store Connect ← Users and Access ← **Integrations** ← App Store Connect API ← Generate API Key (תפקיד App Manager). מורידים את `AuthKey_XXXX.p8` (אפשר רק פעם אחת!), שומרים ב-`~/.appstoreconnect/private_keys/`, ורושמים לעצמך את **Key ID** ואת **Issuer ID**. מגדירים בטרמינל: `export ASC_KEY_ID=...  ASC_ISSUER_ID=...  ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXXX.p8`.
```
cd ~/Bet-El (Bet-El repo only). Pull the latest of claude/additional-file-fas9ie first. Read docs/appstore/GUIDE.md, docs/appstore/LISTING.md and docs/release-update-checklist.md.

PART A - real screenshots from the iOS Simulator (real native Liquid Glass UI):
1. Boot an iPhone 6.9" simulator (iPhone 17 Pro Max, or the newest Pro Max available) and an iPad 13" simulator (iPad Pro 13-inch), iOS 26 runtime. Build the "App" scheme for the simulator (Debug, a dev build - dev builds do not count in the Firebase user counters) and install it.
2. A debug deep link navigates the app: `xcrun simctl openurl booted "betel://shot?screen=<screen>&lang=<he|en>&theme=<light|dark>"` (screens: home chok calendar tehillim prayers meein settings library qr). It only works in dev builds. After the call wait ~4s (chok: ~12s because its data loads from the network), set a clean status bar once (`xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3`), then `xcrun simctl io booted screenshot <file>`.
3. For lang he and en, theme dark and light, and the 8 screens in that order (01-home 02-chok 03-calendar 04-tehillim 05-prayers 06-meein 07-settings 08-library, plus 09-qr), save to: dark -> docs/appstore/raw-device/<lang>-<NN>-<name>.png (and raw-device-ipad/ for the iPad), light -> docs/appstore/raw-device-light/ (and raw-device-ipad-light/). Look at EVERY screenshot yourself: no overlay/launch logo, no Hebrew leaking into the English UI, no cut-off text, home not empty. Retake anything wrong.
4. Run `node scripts/appstore-compose.mjs he,en` (dark) and `node scripts/appstore-compose.mjs he,en light` (light). Outputs: docs/appstore/screenshots/ and screenshots-light/ (iphone-6.9 = 1320x2868, ipad-13 = 2064x2752). Check a sample of the outputs visually.
5. Widgets and Lock Screen cannot be captured automatically: skip them, and tell me which 2 images I should take myself on the iPhone.

PART B - upload to App Store Connect with fastlane (install with `brew install fastlane` if missing), using the App Store Connect API key from env ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH. NEVER print, log or commit those values or the .p8 file.
1. Locales: he -> "he", en -> "en-US", fr -> "fr-FR", ru -> "ru". Georgian is NOT available in App Store Connect - skip it.
2. Create fastlane/metadata/<locale>/ from docs/appstore/LISTING.md (name.txt, subtitle.txt, promotional_text.txt, keywords.txt, description.txt, release_notes.txt from the What's New in docs/release-update-checklist.md, support_url, marketing_url, privacy_url) and fastlane/screenshots/<locale>/ from the DARK iphone-6.9 and ipad-13 folders (keep numeric order; for locales without simulator shots use the web-generated screenshots/ ones). Do not commit fastlane/ (add to .gitignore) unless it is only text metadata.
3. Upload the build: archive the App scheme (Release, build number 6), export for app-store-connect and upload (fastlane pilot upload / xcodebuild -exportArchive with destination upload / xcrun altool). Wait until processing finishes.
4. Create the 2.0 version and upload metadata + screenshots with `fastlane deliver` (skip_binary_upload, force true, submit_for_review FALSE, automatic_release FALSE), select build 6, fill App Review notes from docs/release-update-checklist.md section 3.
5. STOP before submitting. Print a Hebrew checklist of what is ready in App Store Connect and what I must still do by hand (App Privacy answers, age rating questionnaire, export compliance, pressing "Submit for Review"). I will submit myself after checking.
```

---
## פרומט 3 – התראות דרך Firebase (שישלחו מהאפליקציה האמיתית, ושאפשר גם לתזמן)
**חשוב לדעת:** ההתראות הקיימות הן Web Push של FCM – הן **לא עובדות באפליקציית ה-iOS הנייטיב** (WKWebView לא תומך ב-Web Push). כדי לשלוח התראות אמיתיות לאייפונים צריך Push נייטיב (APNs). זה אפשרי, ודורש מפתח APNs אחד ממך: developer.apple.com ← Certificates, Identifiers & Profiles ← **Keys** ← "+" ← Apple Push Notifications service (APNs) ← להוריד `AuthKey_XXXX.p8` (פעם אחת) ולרשום Key ID ו-Team ID. את ההעלאה ל-Firebase (Project Settings ← Cloud Messaging ← APNs Authentication Key) עושים בקונסולה, פעם אחת (דקה). נדרש גם תכנית Blaze ב-Firebase (תשלום לפי שימוש, בשימוש הזה בפועל כמעט אפס) כדי לפרוס פונקציות מתוזמנות.
```
cd ~/Bet-El (Bet-El repo only). Pull the latest of claude/additional-file-fas9ie. Firebase project: bet-el-e6812. Goal: real native iOS push notifications through FCM that I can send (a) manually, (b) from a script and (c) on a schedule, all without me touching code.
1. Inspect what exists: index.html Firebase module (pushTokens collection, the Settings toggle), firebase-messaging-sw.js, functions/index.js, capacitor.config.json. Confirm and tell me that Web Push does not work inside the native WKWebView app.
2. Native side: add @capacitor/push-notifications (or the Firebase iOS Messaging SDK via Swift Package Manager) so the app registers for remote notifications, gets the FCM token and stores it in Firestore pushTokens/{token} {platform:'ios', lang, createdAt}. Add the Push Notifications capability + aps-environment entitlement to the App target, the required AppDelegate hooks, GoogleService-Info.plist handling, and register any new custom plugin both in capacitor-native-bridge.js and MainViewController (see CLAUDE.md). Keep the iOS 15 deployment target. Hook the existing Settings notifications toggle to it. Keep everything compile-safe and tell me what you could not verify.
3. Server side (functions/): (a) an authenticated HTTPS function `sendPush` (admin-only: require a secret from Firebase config or an allowed Google account) taking {title, body, lang?, url?} that sends to all pushTokens in batches and deletes invalid tokens; (b) a scheduled function (Cloud Scheduler, timezone Asia/Jerusalem) that every Thursday 18:00 sends "this week's parasha" and every Friday ~2h before candle lighting a short reminder (reuse the app's own texts; keep them in a small config so I can edit); (c) a CLI script scripts/send-push.mjs "title" "body" that uses a service account on my Mac (never committed) for ad-hoc sends. Deploy the functions with the firebase CLI and test with a real device token.
4. Tell me exactly which one manual step is left (uploading the APNs key to Firebase) and how to send from the Firebase Console afterwards (Engage > Messaging > New campaign > target the iOS app).
5. Report in Hebrew. Do not send any notification to real users without asking me first.
```

---
## פרומט 4 – קריסת הווידג'טים (BetElWidgetBundle)
Claude Code מצא קריסות `EXC_BREAKPOINT` בתוך ה-getter של `BetElWidgetBundle.body` (ה-extension קורס לפני שהוא בונה את רשימת הווידג'טים) – זה מסביר גלריה ריקה ו-Live Activity שלא מופיע. הפרומט:
```
cd ~/Bet-El (Bet-El repo only). Widgets still crash in BetElWidgetBundle.body (EXC_BREAKPOINT) and the widget gallery shows nothing.
1. Read the newest BetElWidget crash reports (~/Library/Logs/DiagnosticReports, device crash logs via Xcode/devicectl). Print the exception message / "asi" (application specific information), termination reason and the symbolicated top frames - not just "EXC_BREAKPOINT".
2. Suspect #1: the `if #available` blocks inside WidgetBundle.body in ios/App/BetElWidget/BetElWidgetBundle.swift (9 widgets incl. StandBy, 3 lock-screen widgets and the Live Activity). Suspect #2: a widget whose Provider/body traps on construction, or a Live Activity widget in the same bundle (ActivityConfiguration needs NSSupportsLiveActivities in the APP Info.plist, and BetElActivityAttributes compiled in both targets).
3. Bisect: build variants of the bundle with only the 5 plain widgets, then add the others one at a time, until you know exactly which one crashes. Install and check the crash log each time.
4. Fix it for real. If the cause is the availability checks, raise ONLY the BetElWidget extension's IPHONEOS_DEPLOYMENT_TARGET to 17.0 (the app target must stay 15.0) and remove the `if #available` wrappers; if it is one widget, fix that widget. Keep widgets compile-safe, commit and push to the same branch (never my local DEVELOPMENT_TEAM change).
5. Reinstall and ask me to open the widget gallery (long-press home screen, +). Then re-read the crash logs and tell me in Hebrew whether a new crash appeared, and whether the Live Activity can start.
```

---
## לפני פרומט Firebase: התחברות (פעם אחת, אינטראקטיבי)
Claude Code לא יכול להתחבר ל-Firebase לבד. בטרמינל, פעם אחת: `npx firebase-tools login` (נפתח דפדפן, מאשרים), ואז `npx firebase-tools use bet-el-e6812`. אחרי זה פרומט 1 (שלב 3) יעבוד.

---
## פרומט מאסטר – הכל ברצף (בלי Firebase), כדי להמשיך ב-Remote Control מהטלפון
בטרמינל, בתיקיית הפרויקט: `cd ~/Bet-El && claude remote-control` – הסשן מופיע באפליקציית Claude Code בטלפון ואפשר להמשיך משם. (הפרומט למטה אפשר להדביק כבר בסשן או לשלוח מהטלפון.)
```
cd ~/Bet-El (Bet-El repo ONLY). Work through these in order, autonomously, and report in Hebrew. Do NOT touch Firebase (I will do the Firestore rule myself). Do NOT submit the app for review. Never print, log or commit the App Store Connect key (env ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH) or my local DEVELOPMENT_TEAM change.
A. git stash if needed, pull origin claude/additional-file-fas9ie (latest), stash pop. npm run cap:sync. Build and install the App scheme on my iPhone (com.beitel.tehilim, build 6, widget embedded and signed). Fix compile errors minimally (iOS 15 app target, #available for newer APIs), commit and push.
B. WIDGETS (they still do not appear): follow "פרומט 4" in docs/claude-code-prompts.md - read the newest BetElWidget crash reports with the real exception message, bisect the widget bundle (ios/App/BetElWidget/BetElWidgetBundle.swift), fix the cause (if it is the `if #available` blocks, raise ONLY the widget extension target to iOS 17.0 and remove them), reinstall, then ask me to open the widget gallery and re-check the crash logs.
C. SCREENSHOTS from the iOS Simulator (real native UI): follow "פרומט 2 / PART A" in docs/claude-code-prompts.md - iPhone 6.9" and iPad 13" simulators, deep link `betel://shot?screen=...&lang=he|en&theme=dark|light`, clean status bar, 8 screens + qr, save into docs/appstore/raw-device[-light|-ipad|-ipad-light]/, LOOK at every image (no launch logo, no Hebrew leaking in English, nothing cut off), then `node scripts/appstore-compose.mjs he,en` and `... he,en light`. Replace the web-made screenshots in docs/appstore/screenshots*/ for he and en with these.
D. APP STORE CONNECT upload with fastlane using my API key from the env vars: follow "פרומט 2 / PART B" (locales he, en-US, fr-FR, ru; Georgian does not exist in App Store Connect). Upload build 6 and the 2.0 metadata + screenshots, select the build, fill the review notes - and STOP before "Submit for Review".
E. Finish with a Hebrew checklist: what is ready, what failed, and what only I can do (App Privacy answers, age rating, export compliance, widget screenshots from my iPhone, pressing Submit). Commit and push everything except secrets.
```

---
## פרומט 5 – תמונות חנות אמיתיות מהסימולטור + עיצוב שיווקי, ובדיקת ההדר
```
cd ~/Bet-El (Bet-El repo ONLY). git pull origin claude/additional-file-fas9ie first. Never print/commit the ASC key or my DEVELOPMENT_TEAM change. Do NOT submit for review.
PART 1 - HEADER (still broken on my real iPhone): in the Simulator (iPhone 17 Pro, iOS 26), open Chok LeYisrael, Torah reader, Tehillim, Calendar and Library sub-screens. Scroll down and up with real touch (simctl/AppleScript/idb) and take screenshots at each state. The header must tuck away on scroll-down and return on scroll-up, never be transparent (text running under it), never leave a gap or jump. Check NativeTopBar.setCollapsed / setTopBarCollapsed / initNavScrollHide and the HTML .topbar fallback. Fix what you SEE is wrong, reinstall, re-screenshot, and show me before/after in Hebrew.
PART 2 - STORE SCREENSHOTS, REAL SIMULATOR ONLY (no Playwright/web screenshots): for iPhone 6.9" (iPhone 17 Pro Max) and iPad 13" (iPad Pro 13"), languages he and en, themes dark and light: set status bar clean (xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3), open each screen via `xcrun simctl openurl booted "betel://shot?screen=<x>&lang=<he|en>&theme=<dark|light>"` and save to docs/appstore/raw-device[-light][-ipad][-ipad-light]/<lang>-<NN>-<name>.png : 01-home, 02-chok, 03-calendar, 04-tehillim, 05-prayers, 06-meein, 07-settings, 08-library, 09-qr. Wait for the screen to fully render (no launch logo, no spinner). LOOK at every image: no Hebrew in English, nothing clipped.
PART 3 - DESIGN: then run `node scripts/appstore-slides.mjs he,en dark` and `node scripts/appstore-slides.mjs he,en light` (and with the iPad args if the script supports them; if not, extend it - same design at 2064x2752). Each output slide must be a real marketing design (eyebrow, big headline with gold accent word, sub-line, callouts, device frame) and NOT the bare screen. View every output; fix overlaps (e.g. callout over the sub-line) in the script. Output goes to docs/appstore/slides*/<lang>/<device>/.
PART 4 - copy those finished slides into the fastlane screenshots folders for he and en-US (iPhone 6.9 + iPad 13, dark set first, light as extra if limit 10 allows), upload with fastlane deliver using ASC_KEY_ID/ASC_ISSUER_ID/ASC_KEY_PATH, STOP before Submit. Commit and push (except secrets). Report in Hebrew.
```
