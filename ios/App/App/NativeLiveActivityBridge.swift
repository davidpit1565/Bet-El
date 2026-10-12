import Foundation
import UIKit
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
/// without this process staying alive.
///
/// Always on: `refresh()` runs from JS (`syncWidgetData()` - saveS(), a streak
/// bump, boot) and natively on every launch and every return to the foreground.
/// Each run keeps exactly one active Activity: it starts one when none is running
/// (including after the user swiped it away or iOS ended it), ends and restarts it
/// once its zman has passed (sunrise/sunset boundary), replaces it when the
/// language changed, and replaces it after ~7.5h since iOS ends Live Activities
/// at about 8h. The content also carries the following zman, so the widget views
/// roll over by themselves if the system re-renders after the boundary before the
/// app runs again - the countdown never shows an elapsed time.
@objc(NativeLiveActivityBridge)
public class NativeLiveActivityBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeLiveActivityBridge"
    public let jsName = "NativeLiveActivity"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "refresh", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "end", returnType: CAPPluginReturnPromise),
    ]

    override public func load() {
        NotificationCenter.default.addObserver(self, selector: #selector(appForegrounded),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
        appForegrounded()
    }

    @objc private func appForegrounded() {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            NativeLiveActivityBridge.refreshActivity()
        }
        #endif
    }

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
    /// iOS ends a Live Activity after about 8 hours; replace ours a bit before that.
    private static let maxAge: TimeInterval = 7.5 * 60 * 60

    @available(iOS 16.2, *)
    private static func refreshActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let snapshot = BetElSharedData.read()
        let now = Date()
        let upcoming = nextZmanim(latitude: snapshot.latitude, longitude: snapshot.longitude, after: now)
        guard let next = upcoming.first else { return }
        let following = upcoming.count > 1 ? upcoming[1] : nil

        let state = BetElActivityAttributes.ContentState(
            zmanLabel: WidgetL10n.t(next.label, lang: snapshot.lang), endDate: next.date,
            startDate: now,
            nextLabel: following.map { WidgetL10n.t($0.label, lang: snapshot.lang) }, nextDate: following?.date)
        let title = WidgetL10n.t("nextZman", lang: snapshot.lang)
        let rtl = snapshot.lang == "he"

        let all = Activity<BetElActivityAttributes>.activities
        let live = all.filter { $0.activityState == .active || $0.activityState == .stale }
        // Anything not live (ended / dismissed) is just cleaned up.
        for a in all where !live.contains(where: { $0.id == a.id }) { Task { await a.end(nil, dismissalPolicy: .immediate) } }

        if let existing = live.first {
            for extra in live.dropFirst() { Task { await extra.end(nil, dismissalPolicy: .immediate) } }
            let age = existing.attributes.startedAt.map { now.timeIntervalSince($0) } ?? .infinity
            let samePresentation = existing.attributes.title == title && existing.attributes.rtl == rtl
            if samePresentation && age < maxAge {
                // Same zman as before keeps its original start, so the range doesn't jump.
                var s = state
                if existing.content.state.endDate == next.date { s.startDate = existing.content.state.startDate ?? now }
                Task { await existing.update(ActivityContent(state: s, staleDate: next.date)) }
                return
            }
            // Title/direction are immutable attributes (language change), or the Activity
            // is close to iOS's ~8h limit - replace it with a fresh one.
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
        }
        let attributes = BetElActivityAttributes(title: title, rtl: rtl, startedAt: now)
        do {
            _ = try Activity<BetElActivityAttributes>.request(attributes: attributes,
                                                               content: ActivityContent(state: state, staleDate: next.date))
        } catch {
            // Starting a Live Activity can fail for reasons outside this
            // app's control (user disabled them systemwide, too many
            // already running, etc.) - there's no useful recovery beyond
            // simply not showing one, so this is deliberately silent.
        }
    }

    /// The next two of dawn/sunrise/sunset after `now` (today's, then tomorrow's) -
    /// mirrors Provider.swift's "what's the next zman" logic.
    @available(iOS 16.2, *)
    private static func nextZmanim(latitude: Double, longitude: Double, after now: Date) -> [(label: String, date: Date)] {
        var out: [(label: String, date: Date)] = []
        for offset in 0...2 {
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: now),
                  let t = Solar.times(for: day, latitude: latitude, longitude: longitude) else { continue }
            for z in [("dawn", t.dawn), ("sunrise", t.sunrise), ("sunset", t.sunset)] where z.1 > now {
                out.append((label: z.0, date: z.1))
                if out.count == 2 { return out }
            }
        }
        return out
    }
    #endif
}
