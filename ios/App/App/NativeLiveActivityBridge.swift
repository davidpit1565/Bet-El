import Foundation
import Capacitor
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Exposes `window.Capacitor.Plugins.NativeLiveActivity.*` to the web app -
/// a Live Activity (Lock Screen banner + Dynamic Island) showing a live
/// countdown to the next zman (dawn/sunrise/sunset only - the same simple solar
/// calculation `BetElWidget`'s own Provider.swift already uses, not the
/// app's full halachic zmanim, see Solar.swift's own header comment for
/// why that's out of scope here too).
///
/// Deliberately local-only (no push-to-update capability, so no
/// `NSSupportsLiveActivitiesFrequentUpdates`/push entitlement needed
/// beyond the plain `NSSupportsLiveActivities` Info.plist key) - once
/// started with a concrete end date, iOS keeps the countdown ticking on
/// its own (via `Text(timerInterval:)` in BetElLiveActivityWidget.swift)
/// without this process staying alive, exactly like a plain system Timer
/// notification would.
///
/// `refresh()` is called from the same JS call sites that already call
/// `syncWidgetData()` (saveS(), a streak bump, and once at boot) rather
/// than on its own separate trigger - recomputes the next zman from the
/// same App Group snapshot (latitude/longitude/theme/lang) the Home
/// Screen widget already reads, and starts a new Activity, updates the
/// running one if the zman hasn't changed, or ends it once that zman's
/// own moment has passed (the next `refresh()` call picks up the
/// following one).
@objc(NativeLiveActivityBridge)
public class NativeLiveActivityBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeLiveActivityBridge"
    public let jsName = "NativeLiveActivity"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "refresh", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "end", returnType: CAPPluginReturnPromise),
    ]

    @objc func refresh(_ call: CAPPluginCall) {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            NativeLiveActivityBridge.refreshActivity()
        }
        #endif
        call.resolve()
    }

    @objc func end(_ call: CAPPluginCall) {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            Task { for activity in Activity<BetElActivityAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) } }
        }
        #endif
        call.resolve()
    }

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private static func refreshActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let snapshot = BetElSharedData.read()
        let now = Date()
        guard let next = nextZman(latitude: snapshot.latitude, longitude: snapshot.longitude, after: now) else { return }

        let state = BetElActivityAttributes.ContentState(zmanLabel: WidgetL10n.t(next.label, lang: snapshot.lang), endDate: next.date)
        let content = ActivityContent(state: state, staleDate: next.date.addingTimeInterval(60 * 30))

        if let existing = Activity<BetElActivityAttributes>.activities.first {
            Task { await existing.update(content) }
            return
        }
        let attributes = BetElActivityAttributes(title: WidgetL10n.t("nextZman", lang: snapshot.lang))
        do {
            _ = try Activity<BetElActivityAttributes>.request(attributes: attributes, content: content)
        } catch {
            // Starting a Live Activity can fail for reasons outside this
            // app's control (user disabled them systemwide, too many
            // already running, etc.) - there's no useful recovery beyond
            // simply not showing one, so this is deliberately silent
            // rather than surfacing a native alert for a background sync.
        }
    }

    /// Mirrors Provider.swift's own "what's the next zman" logic (today's
    /// dawn/sunrise/sunset, or tomorrow's dawn once today's sunset has
    /// passed) - kept here rather than shared, since the widget's version
    /// also needs the *second* upcoming zman for its large layout, which
    /// this simpler countdown-only use doesn't.
    @available(iOS 16.2, *)
    private static func nextZman(latitude: Double, longitude: Double, after now: Date) -> (label: String, date: Date)? {
        guard let today = Solar.times(for: now, latitude: latitude, longitude: longitude) else { return nil }
        if now < today.dawn { return ("dawn", today.dawn) }
        if now < today.sunrise { return ("sunrise", today.sunrise) }
        if now < today.sunset { return ("sunset", today.sunset) }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        guard let next = Solar.times(for: tomorrow, latitude: latitude, longitude: longitude) else { return nil }
        return ("dawn", next.dawn)
    }
    #endif
}
