var capacitorNativeBridge = (function (core) {
    'use strict';

    // These are this app's own custom native-only Swift plugins (iOS 26
    // Liquid Glass UI: NativeTopBarBridge.swift, NativeToolsFabBridge.swift,
    // NativeModalBridge.swift, NativeSettingsBridge.swift,
    // NativeToastBridge.swift, NativeHapticsBridge.swift,
    // NativeTabBarBridge.swift, plus the unrelated-to-Liquid-Glass
    // BetElWidgetBridge.swift used by updateSharedData() to push today's
    // data to the home-screen widget) - unlike @capacitor/app or
    // @capacitor/local-notifications, they ship no npm package of their
    // own, so there is no vendored UMD bundle that calls
    // `core.registerPlugin(...)` for them. Without that JS-side call,
    // `window.Capacitor.Plugins.<Name>` never exists (Capacitor's bridge
    // only creates that proxy object when registerPlugin() runs - the
    // Swift side alone isn't enough), so every `NATIVE_TOPBAR`/
    // `NATIVE_TOOLS_FAB`/etc check in index.html stayed permanently false
    // and none of this native UI ever activated, even though the Swift
    // code was correct and the app built and ran fine.
    //
    // Registered only on native platforms (no `web` implementation given)
    // so `window.Capacitor.Plugins.X` stays exactly as undefined on the
    // web/PWA build as it always was - the existing `!!Capacitor.Plugins.X`
    // truthy checks throughout index.html depend on that.
    // iOS ONLY: Android has none of these Swift plugins, and registering the JS proxies there makes
    // index.html believe a native UI exists, so it hides its own HTML home/nav/tools -> blank screen.
    if (core.Capacitor.isNativePlatform() && core.Capacitor.getPlatform() === 'ios') {
        core.registerPlugin('NativeTopBar');
        core.registerPlugin('NativeToolsFab');
        core.registerPlugin('NativeModal');
        core.registerPlugin('NativeSettings');
        core.registerPlugin('NativeToast');
        core.registerPlugin('NativeHomeEdit');
        core.registerPlugin('NativeCalendar');
        core.registerPlugin('NativeLibrary');
        core.registerPlugin('NativeHome');
        core.registerPlugin('NativeSystem');
        core.registerPlugin('NativeHaptics');
        core.registerPlugin('NativeTabBar');
        core.registerPlugin('BetElWidgetBridge');
        core.registerPlugin('NativeLiveActivity');
        core.registerPlugin('NativeSpotlight');
        // @capacitor/splash-screen ships no vendored UMD bundle either (see the
        // note above): index.html's launch screen calls SplashScreen.hide() as
        // soon as it has painted, so the static native image doesn't linger.
        // @capacitor-firebase/messaging (native APNs/FCM push) ships an ES module
        // only, so it gets the same treatment.
        if (!core.Capacitor.Plugins.FirebaseMessaging) core.registerPlugin('FirebaseMessaging');
    }

    // SplashScreen is a real plugin on both iOS and Android.
    if (core.Capacitor.isNativePlatform() && !core.Capacitor.Plugins.SplashScreen) core.registerPlugin('SplashScreen');

    return core;

})(capacitorExports);
