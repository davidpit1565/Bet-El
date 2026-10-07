import Foundation
import Capacitor
import WidgetKit

/// Exposes `window.Capacitor.Plugins.BetElWidgetBridge.updateSharedData(...)`
/// to the web app (see index.html's syncWidgetData()). Writes into the
/// App Group's shared UserDefaults via BetElSharedData, then asks
/// WidgetKit to reload the widget's timelines so the change shows up
/// promptly rather than waiting for the next scheduled reload.
@objc(BetElWidgetBridge)
public class BetElWidgetBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "BetElWidgetBridge"
    public let jsName = "BetElWidgetBridge"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "updateSharedData", returnType: CAPPluginReturnPromise)
    ]

    @objc func updateSharedData(_ call: CAPPluginCall) {
        let streakCount = call.getInt("streakCount") ?? 0
        let streakBest = call.getInt("streakBest") ?? 0
        let theme = call.getString("theme") ?? "dark"
        let lang = call.getString("lang") ?? "he"
        let latitude = call.getDouble("latitude") ?? BetElSharedData.Snapshot.placeholder.latitude
        let longitude = call.getDouble("longitude") ?? BetElSharedData.Snapshot.placeholder.longitude
        let candleTimeISO = call.getString("candleTime")
        let candleLabel = call.getString("candleLabel")
        let dayLabelsJSON = call.getString("dayLabels")
        let zmanimJSON = call.getString("zmanim")
        let omerJSON = call.getString("omer")
        let candlesJSON = call.getString("candles")

        let snapshot = BetElSharedData.Snapshot(
            streakCount: streakCount,
            streakBest: streakBest,
            theme: theme,
            lang: lang,
            latitude: latitude,
            longitude: longitude,
            candleTimeISO: candleTimeISO,
            candleLabel: candleLabel,
            dayLabelsJSON: dayLabelsJSON,
            zmanimJSON: zmanimJSON,
            omerJSON: omerJSON,
            candlesJSON: candlesJSON
        )
        BetElSharedData.write(snapshot)

        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        call.resolve()
    }
}
