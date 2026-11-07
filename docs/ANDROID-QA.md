# Android and Web QA

This repository has a GitHub Actions workflow at `.github/workflows/android-qa.yml`.

## What it checks

### Web regression
- Installs the repository's locked npm dependencies.
- Installs the Playwright-managed Chromium browser.
- Starts the app from the repository root.
- Runs the existing `npm run test:sweep` navigation regression.
- Saves a screenshot after each navigation step and uploads the images as a workflow artifact.

### Android emulator smoke test
- Regenerates Capacitor's Android assets with `npm run cap:sync`.
- Builds an unsigned debug APK.
- Installs and launches `com.beitel.tehilim` on an Android 36 Pixel 6 emulator.
- Confirms the app process remains alive after launch.
- Saves the emulator screen and Android runtime exception log as workflow artifacts.

## Run it

The workflow runs on pushes to `automation/android-qa`, pull requests targeting `main`, and manual dispatch from the GitHub Actions tab.

## Important limitations

- These are automated engineering checks, not human closed-test participation.
- Emulator launches do not count as Play Store testers and cannot replace the required real tester accounts or their genuine engagement.
- The emulator test currently verifies build, installation, launch, process survival, and fatal Android runtime exceptions. It does not yet validate every native feature, notification delivery, widgets, location behavior, or real-device compatibility.
- The workflow does not sign or upload a release AAB and does not publish anything to Google Play.
