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
        CAPPluginMethod(name: "hideSearch", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showSearch", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setSearchText", returnType: CAPPluginReturnPromise),
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
        let isDark = call.getBool("isDark") ?? false
        DispatchQueue.main.async {
            NativeTabBarBridge.activeController?.setTabBarTheme(isDark: isDark)
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

    /// Closes the native search field (called by JS when it navigates away from the search screen).
    @objc func hideSearch(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            NativeTabBarBridge.activeController?.hideNativeSearchBar(clear: false)
        }
        call.resolve()
    }

    /// Puts the bar into its Search-tab state (App Store style: the bar collapses into the previous tab's circle and a
    /// glass search field takes its place). Called by JS whenever the Search screen renders - also when it was reached
    /// from a search box or shortcut inside the app rather than from the tab bar itself. `focus` raises the keyboard.
    @objc func showSearch(_ call: CAPPluginCall) {
        let focus = call.getBool("focus") ?? false
        DispatchQueue.main.async {
            NativeTabBarBridge.activeController?.showNativeSearchBar(focus: focus)
        }
        call.resolve()
    }

    /// Mirrors a query chosen on the page (a suggestion / recent search) into the native field.
    @objc func setSearchText(_ call: CAPPluginCall) {
        let text = call.getString("text") ?? ""
        DispatchQueue.main.async {
            NativeTabBarBridge.activeController?.setNativeSearchText(text)
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
