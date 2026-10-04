import Foundation
import Capacitor

/// Exposes `window.Capacitor.Plugins.NativeToolsFab.*` to the web app so it
/// can drive the real native floating tools button (font size/theme/
/// autoscroll/home) added in MainViewController - a genuine iOS 26 Liquid
/// Glass (`UIGlassEffect`) floating action button instead of the CSS
/// `.reader-tools`/`.rt-fab`/`.rt-panel` approximation, mirroring how
/// NativeTabBarBridge already replaced the bottom nav. JS stays the single
/// source of truth for font scale/theme/autoscroll state; this plugin only
/// relays taps back to JS (see MainViewController's onAction closure) and
/// displays whatever state JS pushes via setState.
@objc(NativeToolsFabBridge)
public class NativeToolsFabBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeToolsFabBridge"
    public let jsName = "NativeToolsFab"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "configure", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setState", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "show", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hide", returnType: CAPPluginReturnPromise),
    ]

    /// Set by MainViewController.viewDidLoad(), same pattern as
    /// NativeTabBarBridge.activeController.
    static weak var activeController: MainViewController?

    @objc func configure(_ call: CAPPluginCall) {
        let showAutoscroll = call.getBool("showAutoscroll") ?? false
        DispatchQueue.main.async {
            NativeToolsFabBridge.activeController?.configureToolsFab(showAutoscroll: showAutoscroll)
        }
        call.resolve()
    }

    @objc func setState(_ call: CAPPluginCall) {
        let fontScalePercent = call.getInt("fontScalePercent") ?? 100
        let isDarkTheme = call.getBool("isDarkTheme") ?? false
        let isAutoscrollActive = call.getBool("isAutoscrollActive") ?? false
        DispatchQueue.main.async {
            NativeToolsFabBridge.activeController?.setToolsFabState(
                fontScalePercent: fontScalePercent,
                isDarkTheme: isDarkTheme,
                isAutoscrollActive: isAutoscrollActive
            )
        }
        call.resolve()
    }

    @objc func show(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            NativeToolsFabBridge.activeController?.setToolsFabVisible(true)
        }
        call.resolve()
    }

    @objc func hide(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            NativeToolsFabBridge.activeController?.setToolsFabVisible(false)
        }
        call.resolve()
    }
}
