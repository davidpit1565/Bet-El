# Prompt for the Mac terminal Claude (next test build: iOS TestFlight + Android)

Copy everything below into `claude` in the repo folder on the Mac. It replaces the older `RELEASE-2-0-8-MAC-PROMPT.md` for this build, because that one starts from the old `claude/release-2-0-8` branch (this build starts from `main`, which already contains everything below).

---
You are on David's MacBook in the Bet-El repo. David is in Belgium. Goal: ONE testing build for iOS (TestFlight, INTERNAL testers only, never attached to an App Store version, never submitted) and ONE Android test build. Hard rules: never print the ASC key id / issuer / key path / team id; every upload needs David's typed approval in this terminal; David alone presses Submit for Review; do not touch any submission that is Waiting for Review. Read CLAUDE.md first ("Release workflow", "Before every push", "Always build for the NEWEST iOS").

## What is in `main` since the last build (so you know what to expect and test)
- Siddur special-day fixes: Chanukah by Hebrew date, no Tachanun on Shabbat/Yom Tov/Chol HaMoed/Tisha B'Av, Purim by city (`PURIM_WALLED_CITIES`), Shabbat/Yom Tov start at sunset, Oseh HaShalom from 1 Tishrei, "sukkat David" added after the Livyatan line (he + en/fr/ru/ka transliteration; `data/data-version.json` bumped), Rosh Chodesh fix in Birkat HaMazon.
- Android: widgets fix (`BetElWidgets.java` no `setGravity`, new layouts, `WidgetRenderTest`), `NativeShareBridge.java` (system share sheet for "share today's details"), iOS-style Settings + glass-style polish for the HTML (Android/web) UI.
- Security hardening (escaped dedication names, App Store URL allow-list, CSP `object-src 'none'`), offline-download UI hidden, tefillin-mirror freeze fix.
- Visit statistics: each counted session writes aggregate counters to Firestore `visitLog/<Israel day>` (hour, platform, new/returning, time zone as a rough country). Needs the updated Firestore rules published (David does that in the Firebase console, rules file is `firestore.rules`).

## iOS (TestFlight, internal only)
1. `git fetch origin && git checkout -B claude/testflight-next origin/main`.
2. `fastlane ios asc_status` (read-only): find the highest existing version and build number. Set `MARKETING_VERSION` (David wants 2.0.8 unless ASC already has a higher or closed 2.0.8; tell him if so) and `CURRENT_PROJECT_VERSION = highest build + 1` in `ios/App/App.xcodeproj/project.pbxproj`, all 4 places each (App Debug+Release and the Widget Extension Debug+Release).
3. `npm ci && npm run cap:sync`, then Archive Release and export the IPA (`fastlane/ExportOptions.plist`). The Swift was never compile-verified in the cloud: fix compile errors if any and tell David exactly what you changed.
4. Before uploading, run on a simulator or device and report: app launches, Home/Library/Calendar/Settings render, a siddur prayer opens, no crash.
5. After David's typed approval: `fastlane ios upload_testflight` (internal testing only). Report build number, upload status and what is left for David.

## Android
1. Same checkout. In `android/app/build.gradle` raise `versionCode` (currently 14) to the highest in Play Console + 1 (ask David or read it from his Play Console if you can; otherwise use 15) and `versionName` (currently 2.0.11) to 2.0.12 unless David says otherwise.
2. `npm ci && npm run cap:sync`, then from `android/`: `./gradlew bundleRelease` (Play) and `./gradlew assembleDebug` (a debug APK David can sideload to test quickly). Signing for the release bundle uses David's existing keystore settings; never print passwords. Report any build errors and what you changed (the Java was only compile-checked in the cloud: `NativeShareBridge`, widgets).
3. Do not upload to Play. Give David the file paths of the `.aab` and the debug `.apk`.

## What David will test (Hebrew checklist for him, report back with results)
iOS: siddur special days (Shabbat shows no Tachanun; Friday after sunset shows Shabbat text in Birkat HaMazon), Purim city logic, Sukkot "sukkat David" line, native Settings still fine, widgets still update, no new crash.
Android: add all 4 widgets from the widget picker (open the app once first), they show real data and the countdown ticks; "share today's details" opens the system share sheet; Settings look like iOS Settings; no blank screen.

Report in Hebrew. List every file you changed.
