import Foundation
import UIKit
import Capacitor

/// Exposes `window.Capacitor.Plugins.NativeHaptics.*` so the web app can
/// trigger real `UIFeedbackGenerator` taps at the same interaction points
/// that already feel tactile on native iOS (marking a chapter/section
/// read, toggling a favorite, hitting a reading milestone) instead of
/// having no haptic feedback at all, since none of that is reachable from
/// a WKWebView on its own. A no-op everywhere else (web/PWA/Android),
/// same `window.Capacitor.Plugins.X && ...` guarded pattern as every
/// other native-only bridge in index.html (NativeTabBar, NativeToolsFab,
/// NativeModal).
@objc(NativeHapticsBridge)
public class NativeHapticsBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeHapticsBridge"
    public let jsName = "NativeHaptics"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "impact", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "notification", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "selection", returnType: CAPPluginReturnPromise),
    ]

    @objc func impact(_ call: CAPPluginCall) {
        let style = call.getString("style") ?? "light"
        DispatchQueue.main.async {
            let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
            switch style {
            case "heavy": feedbackStyle = .heavy
            case "medium": feedbackStyle = .medium
            case "rigid": feedbackStyle = .rigid
            case "soft": feedbackStyle = .soft
            default: feedbackStyle = .light
            }
            UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
        }
        call.resolve()
    }

    @objc func notification(_ call: CAPPluginCall) {
        let type = call.getString("type") ?? "success"
        DispatchQueue.main.async {
            let feedbackType: UINotificationFeedbackGenerator.FeedbackType
            switch type {
            case "warning": feedbackType = .warning
            case "error": feedbackType = .error
            default: feedbackType = .success
            }
            UINotificationFeedbackGenerator().notificationOccurred(feedbackType)
        }
        call.resolve()
    }

    @objc func selection(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        call.resolve()
    }
}
