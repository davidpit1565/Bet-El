import Foundation
import Capacitor

/// Exposes `window.Capacitor.Plugins.NativeTopBar.*` to the web app so it
/// can drive the real native floating header bar added in
/// MainViewController - a genuine iOS 26 Liquid Glass (`UIGlassEffect`)
/// bar instead of the CSS `.topbar` `backdrop-filter` approximation,
/// mirroring how NativeTabBarBridge/NativeToolsFabBridge already replaced
/// the bottom nav and the tools FAB. JS stays the single source of truth
/// for the current title/back/actions state; a back tap or a trailing
/// action tap both relay to one fixed JS entry point each
/// (`window.NativeTopBarHost.onBack()`/`.onAction(id)`) rather than this
/// plugin trying to encode the actual behavior itself, since some
/// screens' back action is more than a plain `go(tab)` (e.g. clearing a
/// filter variable first) and different screens attach different meaning
/// to the same action id - see index.html's `TOPBAR_BACK_ACTION`/
/// `TOPBAR_ACTION_HANDLERS`.
@objc(NativeTopBarBridge)
public class NativeTopBarBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeTopBarBridge"
    public let jsName = "NativeTopBar"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "configure", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hide", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setCollapsed", returnType: CAPPluginReturnPromise),
    ]

    static weak var activeController: MainViewController?

    @objc func configure(_ call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let backTo = call.getString("backTo") ?? ""
        let isRTL = call.getBool("isRTL") ?? true
        let isDark = call.getBool("isDark") ?? false
        let homeLabel = call.getString("homeLabel") ?? ""
        let settingsLabel = call.getString("settingsLabel") ?? ""
        let shareLabel = call.getString("shareLabel") ?? ""
        let actionsRaw = call.getArray("actions") ?? []
        let actions: [(id: String, icon: String, label: String)] = actionsRaw.compactMap {
            guard let dict = $0 as? [String: Any],
                  let id = dict["id"] as? String, let icon = dict["icon"] as? String else { return nil }
            return (id, icon, dict["label"] as? String ?? "")
        }
        // Optional native menu per action (`menu: [{id,title,on}]`): the round button then opens a real UIMenu (system / Liquid
        // Glass on iOS 26, scrolls for long lists) instead of sending a tap to JS - used by the readers' chapter/aliyah pickers.
        var menus: [String: [(id: String, title: String, on: Bool)]] = [:]
        for case let dict as [String: Any] in actionsRaw {
            guard let aid = dict["id"] as? String, let items = dict["menu"] as? [[String: Any]] else { continue }
            menus[aid] = items.compactMap {
                guard let iid = $0["id"] as? String, let t = $0["title"] as? String else { return nil }
                return (iid, t, ($0["on"] as? Bool) ?? false)
            }
        }
        // Optional title button + picker sheet (`titleSheet: {daysTitle, secsTitle, daysAction, secsAction, days:[{id,title,on}], secs:[...]}`).
        func items(_ raw: Any?) -> [TitleSheetItem] {
            (raw as? [[String: Any]] ?? []).compactMap {
                guard let iid = $0["id"] as? String, let t = $0["title"] as? String else { return nil }
                return TitleSheetItem(id: iid, title: t, on: ($0["on"] as? Bool) ?? false)
            }
        }
        var sheet: TitleSheetSpec?
        if let ts = call.getObject("titleSheet") {
            sheet = TitleSheetSpec(
                daysTitle: ts["daysTitle"] as? String ?? "", secsTitle: ts["secsTitle"] as? String ?? "",
                daysAction: ts["daysAction"] as? String ?? "", secsAction: ts["secsAction"] as? String ?? "",
                days: items(ts["days"]), secs: items(ts["secs"]), isRTL: isRTL, isDark: isDark)
        }
        DispatchQueue.main.async {
            NativeTopBarView.titleSheet = sheet
            if sheet != nil { NotificationCenter.default.post(name: TitleSheetViewController.refreshNotification, object: nil) }
            NativeTopBarView.menus = menus
            NativeTopBarBridge.activeController?.configureTopBar(
                title: title, hasBack: !backTo.isEmpty, isRTL: isRTL, isDark: isDark,
                homeLabel: homeLabel, settingsLabel: settingsLabel, shareLabel: shareLabel,
                actions: actions
            )
        }
        call.resolve()
    }

    @objc func setCollapsed(_ call: CAPPluginCall) {
        let collapsed = call.getBool("collapsed") ?? false
        DispatchQueue.main.async { NativeTopBarBridge.activeController?.setTopBarCollapsed(collapsed) }
        call.resolve()
    }

    @objc func hide(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            NativeTopBarBridge.activeController?.setTopBarVisible(false)
        }
        call.resolve()
    }
}
