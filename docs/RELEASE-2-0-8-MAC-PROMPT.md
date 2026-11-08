# Prompt for the Mac terminal Claude (release 2.0.8)

Copy everything below into `claude` in the repo folder on the Mac.

---
You are on David's MacBook in the Bet-El repo. Goal: a full 2.0.8 build to TestFlight (INTERNAL only) plus App Store Connect listing update (texts + new screenshots). Hard rules: never print the ASC key id / issuer / key path / team id; every upload or ASC write needs my typed approval in the terminal first; do NOT submit for review (I press Submit myself); do NOT merge anything to main.

1. `git fetch origin && git checkout claude/release-2-0-8 && git pull`. Read CLAUDE.md ("Release workflow", "Before every push") and docs/appstore/GUIDE.md.
2. Ask ASC (`fastlane ios asc_status`, read-only) for the highest existing version and build number. Set MARKETING_VERSION = 2.0.8 and CURRENT_PROJECT_VERSION = (highest build + 1) in ios/App/App.xcodeproj/project.pbxproj (both configs), commit locally on a testing-only branch (not main).
3. `npm ci && npm run cap:sync`, then Archive Release and export the IPA (fastlane/ExportOptions.plist). Fix compile errors if any (the Swift was never compile-verified in the cloud) and tell me what you changed.
4. Screenshots: new web-based sets are already in docs/appstore/screenshots (dark) and screenshots-light, all languages, iPhone 6.9" and iPad 13". If a simulator/iPhone is available, ALSO capture the native screens (real Liquid Glass home, calendar, library) into docs/appstore/raw-device/<lang>-NN-name.png and re-run `node scripts/appstore-compose.mjs` (details in GUIDE.md); otherwise use the existing ones. Look at several of them before uploading.
5. Listing: texts live in fastlane/metadata (he, en-US, fr-FR, ru; release notes for 2.0.8 are already written there). Review description/promotional text against LISTING.md and the current features; show me any text you want to change before changing it. Then (after my approval) `fastlane ios upload_listing version:2.0.8 build:<N> locales:he,en-US,fr-FR,ru` (check the lane's options in fastlane/Fastfile first).
6. Upload the build to TestFlight internal testing only (`fastlane ios upload_testflight`), after my typed approval. Report build number, upload status, and exactly what is left for me (testing on my iPhone, then pressing Submit).
Report in Hebrew.
