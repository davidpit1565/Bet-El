# Native App Store slides (iPhone 6.9")

Generated from real captures of the native iOS app (Liquid Glass UI), composed onto the brand background with a headline per language.

## 1. Capture raw screens
Boot a 6.9" simulator, set a clean status bar, then for each language/screen relaunch the app with the harness env vars and screenshot:

    xcrun simctl status_bar <UDID> override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
    SIMCTL_CHILD_BETEL_SHOT_SCREEN=<home|chok|calendar|brachot|meein> \
    SIMCTL_CHILD_BETEL_SHOT_LANG=<he|en|fr|ru|ka> \
    SIMCTL_CHILD_BETEL_SHOT_THEME=light \
    xcrun simctl launch --terminate-running-process <UDID> <bundle id>
    sleep 25   # cold start ~20-30s, chok needs ~30s
    xcrun simctl io <UDID> screenshot docs/appstore/raw-native/<lang>-<screen>.png

Clear the override afterwards: `xcrun simctl status_bar <UDID> clear`.

## 2. Compose
    node scripts/appstore-native.mjs he,en,fr,ru,ka

Output: `docs/appstore/native/<lang>/iphone-6.9/NN-name.png` (1320x2868).
Slides 01-05, 07 (Live Activity, HTML mock of the SwiftUI lock screen) and 08 (languages).
Slide 06 (widget sizes) is intentionally not regenerated: keep the existing one in `docs/appstore/widgets/`.
