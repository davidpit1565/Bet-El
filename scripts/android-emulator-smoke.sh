#!/usr/bin/env bash
# Run by reactivecircus/android-emulator-runner. That action executes a multi-line `script:` one line at a time,
# each in its own shell, so `cd`, loops and `if` blocks break. Keeping the steps in a file avoids that.
set -euo pipefail
cd "$(dirname "$0")/.."
cd android
./gradlew --no-daemon assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell monkey -p com.beitel.tehilim 1
sleep 15
mkdir -p ../artifacts
if ! adb shell pidof com.beitel.tehilim; then
  echo 'App is not running 15s after launch; logcat follows'
  adb logcat -d | tail -n 200 | tee ../artifacts/android-logcat-tail.txt
  adb exec-out screencap -p > ../artifacts/android-emulator-home.png || true
  exit 1
fi
adb exec-out screencap -p > ../artifacts/android-emulator-home.png
adb logcat -d -s AndroidRuntime:E > ../artifacts/android-runtime-errors.log
if grep -q "FATAL EXCEPTION" ../artifacts/android-runtime-errors.log; then
  cat ../artifacts/android-runtime-errors.log
  exit 1
fi
# Home-screen widgets: the launcher's picker lists exactly the providers AppWidgetManager knows about.
adb shell dumpsys appwidget > ../artifacts/appwidget-dump.txt || true
# Providers are the app's receivers that listen for APPWIDGET_UPDATE; the system's package manager knows them as soon as the app is installed
# (the appwidget service dump can stay empty until a launcher binds, so it is only kept as an artifact).
adb shell pm query-receivers --brief -a android.appwidget.action.APPWIDGET_UPDATE > ../artifacts/widget-receivers.txt
for w in BetElMainWidget BetElZmanimWidget BetElCandleWidget BetElStreakWidget; do
  grep -q "$w" ../artifacts/widget-receivers.txt || { echo "Widget provider $w is not registered"; cat ../artifacts/widget-receivers.txt; exit 1; }
done
# Applies every widget's RemoteViews like a launcher does (a rejected action = "Can't load widget" on a phone).
# Runs last: connected tests uninstall the app afterwards.
./gradlew --no-daemon connectedDebugAndroidTest
