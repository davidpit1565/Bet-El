import Foundation
import Capacitor

/// Exposes `window.Capacitor.Plugins.NativeTabBar.*` to the web app (see
/// index.html's `syncNativeTabBar()`) so it can drive the real native
/// `UITabBar` added in MainViewController - labels/active tab/visibility
/// all stay controlled from the JS side (the single source of truth for
/// the app's current language and navigation state), the native side
/// only renders whatever it's told.
@objc(NativeTabBarBridge)
public class NativeTabBarBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeTabBarBridge"
    public let jsName = "NativeTabBar"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "configure", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setActive", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setVisible", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setHidden", returnType: CAPPluginReturnPromise),
    ]

    /// Set by MainViewController.viewDidLoad(). Weak since the plugin
    /// instance can outlive a view controller in theory; every method
    /// below already no-ops safely if this is nil (e.g. called before
    /// the root view controller has finished loading).
    static weak var activeController: MainViewController?

    @objc func configure(_ call: CAPPluginCall) {
        let rawItems = call.getArray("items", JSObject.self) ?? []
        let items: [[String: String]] = rawItems.compactMap { obj in
            guard let id = obj["id"] as? String, let label = obj["label"] as? String else { return nil }
            return ["id": id, "label": label]
        }
        let activeTab = call.getString("activeTab") ?? "home"
        let isRTL = call.getBool("isRTL") ?? false
        DispatchQueue.main.async {
            NativeTabBarBridge.activeController?.configure(items: items, activeTab: activeTab, isRTL: isRTL)
        }
        call.resolve()
    }

    @objc func setActive(_ call: CAPPluginCall) {
        let tab = call.getString("tab") ?? "home"
        DispatchQueue.main.async {
            NativeTabBarBridge.activeController?.setActive(tab: tab)
        }
        call.resolve()
    }

    @objc func setVisible(_ call: CAPPluginCall) {
        let visible = call.getBool("visible") ?? true
        DispatchQueue.main.async {
            NativeTabBarBridge.activeController?.setVisible(visible)
        }
        call.resolve()
    }

    @objc func setHidden(_ call: CAPPluginCall) {
        let hidden = call.getBool("hidden") ?? false
        DispatchQueue.main.async {
            NativeTabBarBridge.activeController?.setHidden(hidden)
        }
        call.resolve()
    }
}
