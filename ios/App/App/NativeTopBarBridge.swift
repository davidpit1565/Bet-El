import Foundation
import Capacitor

/// Exposes `window.Capacitor.Plugins.NativeTopBar.*` to the web app so it
/// can drive the real native floating header bar added in
/// MainViewController - a genuine iOS 26 Liquid Glass (`UIGlassEffect`)
/// bar instead of the CSS `.topbar` `backdrop-filter` approximation,
/// mirroring how NativeTabBarBridge/NativeToolsFabBridge already replaced
/// the bottom nav and the tools FAB. JS stays the single source of truth
/// for the current title/back target; this plugin only relays the back
/// tap directly as `window.go(backTo)` (see index.html's topbar() - every
/// covered call site's back button is already exactly that, with no other
/// side effect) and displays whatever title/back state JS pushes via
/// configure.
@objc(NativeTopBarBridge)
public class NativeTopBarBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeTopBarBridge"
    public let jsName = "NativeTopBar"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "configure", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hide", returnType: CAPPluginReturnPromise),
    ]

    static weak var activeController: MainViewController?

    @objc func configure(_ call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let backTo = call.getString("backTo") ?? ""
        let isRTL = call.getBool("isRTL") ?? true
        DispatchQueue.main.async {
            NativeTopBarBridge.activeController?.configureTopBar(title: title, backTo: backTo, isRTL: isRTL)
        }
        call.resolve()
    }

    @objc func hide(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            NativeTopBarBridge.activeController?.setTopBarVisible(false)
        }
        call.resolve()
    }
}
