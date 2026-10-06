import Foundation
import Capacitor

/// Exposes `window.Capacitor.Plugins.NativeSettings.*` to the web app so it
/// can drive a real native `UITableView` (`.insetGrouped`) Settings screen
/// (NativeSettingsView) instead of the HTML `.set-group`/`.set-item` cards'
/// own Liquid-Glass-flavored CSS.
///
/// `configure` takes a full `{title, isDark, sections:[{header, rows:[...]}]}`
/// spec - JS (`nativeSettingsSpec()` in index.html) is the single source of
/// truth for every row's translated label and current value, computed the
/// exact same way the HTML `renderSettings()` already computes them, and
/// resends the whole spec on every change rather than this plugin owning
/// any settings state itself. Each row is one of:
///   - "toggle"     {id, title, subtitle, value: Bool}
///   - "stepper"    {id, title, subtitle, value: String}        (e.g. "100%")
///   - "segmented"  {id, title, subtitle, value: String, options:[{value,label}]}
///   - "select"     {id, title, subtitle, value: String, options:[{value,label}]}
///   - "button"     {id, title, subtitle}
///   - "disclosure" {id, title, subtitle}
///   - "link"       {id, title, subtitle, url: String}          (opened directly, never relayed)
/// Any row may also carry {icon: String (SF Symbol name), iconColor: String
/// ("#RRGGBB")} for a small colored icon badge leading the row, matching
/// the real Settings app's own category rows - used by the top-level
/// category list (nativeSettingsSpec()'s SETTINGS_VIEW==='list' branch).
/// A tap/change on any row but "link" relays `{id, value}` back to
/// `window.NativeSettingsHost.onAction(id, value)` in JS, which either
/// clicks/dispatches a change event on the matching already-rendered HTML
/// control (toggle/select/segmented/stepper/button) or just dismisses this
/// native table back to that HTML screen ("disclosure" rows - see that
/// function's own header comment for why a handful of rows are left that
/// way rather than relayed through a synthetic tap).
@objc(NativeSettingsBridge)
public class NativeSettingsBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeSettingsBridge"
    public let jsName = "NativeSettings"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "configure", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "show", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hide", returnType: CAPPluginReturnPromise),
    ]

    static weak var activeController: MainViewController?

    @objc func configure(_ call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let isDark = call.getBool("isDark") ?? false
        let sectionsRaw = call.getArray("sections") ?? []
        var sections: [NativeSettingsSection] = []
        for case let sectionDict as [String: Any] in sectionsRaw {
            let header = sectionDict["header"] as? String ?? ""
            let rowsRaw = sectionDict["rows"] as? [[String: Any]] ?? []
            let rows: [NativeSettingsRow] = rowsRaw.map { rowDict in
                let optionsRaw = rowDict["options"] as? [[String: Any]] ?? []
                let options: [(value: String, label: String)] = optionsRaw.map {
                    (($0["value"] as? String) ?? "", ($0["label"] as? String) ?? "")
                }
                return NativeSettingsRow(
                    id: rowDict["id"] as? String ?? "",
                    type: rowDict["type"] as? String ?? "",
                    title: rowDict["title"] as? String ?? "",
                    subtitle: rowDict["subtitle"] as? String ?? "",
                    boolValue: rowDict["value"] as? Bool ?? false,
                    stringValue: rowDict["value"] as? String ?? "",
                    options: options,
                    url: rowDict["url"] as? String,
                    icon: rowDict["icon"] as? String,
                    iconColor: rowDict["iconColor"] as? String
                )
            }
            sections.append(NativeSettingsSection(header: header, rows: rows))
        }
        DispatchQueue.main.async {
            NativeSettingsBridge.activeController?.configureSettings(title: title, sections: sections, isDark: isDark)
        }
        call.resolve()
    }

    @objc func show(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            NativeSettingsBridge.activeController?.setSettingsVisible(true)
        }
        call.resolve()
    }

    @objc func hide(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            NativeSettingsBridge.activeController?.setSettingsVisible(false)
        }
        call.resolve()
    }
}
