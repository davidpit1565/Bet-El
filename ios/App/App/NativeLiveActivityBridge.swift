import Foundation
import UIKit
import Capacitor
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Exposes `window.Capacitor.Plugins.NativeLiveActivity.*` to the web app -
/// a Live Activity (Lock Screen banner + Dynamic Island) showing a live
/// countdown to the next zman: dawn, sunrise, midday, sunset, (nightfall when synced)
/// and midnight, taken from the app's own exact times in the shared snapshot.
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
        let upcoming = nextZmanim(snapshot: snapshot, after: now)
        guard let next = upcoming.first else { return }
        let following = upcoming.count > 1 ? upcoming[1] : nil

        let state = BetElActivityAttributes.ContentState(
            zmanLabel: WidgetL10n.t(next.label, lang: snapshot.lang), endDate: next.date,
            startDate: now,
            nextLabel: following.map { WidgetL10n.t($0.label, lang: snapshot.lang) }, nextDate: following?.date,
            zmanKey: next.label,
            upcoming: upcoming.dropFirst().map {
                BetElActivityAttributes.Upcoming(key: $0.label, label: WidgetL10n.t($0.label, lang: snapshot.lang), date: $0.date)
            })
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

    private struct ZRow: Decodable { let d: String; let a: String?; let r: String?; let c: String?; let s: String?; let t: String? }

    /// The next five zmanim after `now`: dawn, sunrise, midday (chatzot), sunset, nightfall
    /// (only when the app syncs it) and midnight (chatzot halayla = midday + 12h, accurate to
    /// about a minute). Uses the app's own exact times from the synced snapshot (the same
    /// table the widgets read) and only falls back to Solar.swift's approximation for days
    /// it doesn't cover. Starts from yesterday so the night after civil midnight still
    /// finds its own midnight.
    @available(iOS 16.2, *)
    private static func nextZmanim(snapshot: BetElSharedData.Snapshot, after now: Date) -> [(label: String, date: Date)] {
        let frac = ISO8601DateFormatter(); frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        func parse(_ s: String?) -> Date? {
            guard let s = s else { return nil }
            return frac.date(from: s) ?? plain.date(from: s)
        }
        let key = DateFormatter(); key.dateFormat = "yyyy-MM-dd"; key.locale = Locale(identifier: "en_US_POSIX")
        var rows: [String: ZRow] = [:]
        if let json = snapshot.zmanimJSON, let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ZRow].self, from: data) {
            for r in decoded { rows[r.d] = r }
        }
        var all: [(label: String, date: Date)] = []
        for offset in -1...3 {
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: now) else { continue }
            var noon: Date?
            if let row = rows[key.string(from: day)], let a = parse(row.a), let r = parse(row.r), let c = parse(row.c), let s = parse(row.s) {
                all += [("dawn", a), ("sunrise", r), ("chatzot", c), ("sunset", s)]
                if let t = parse(row.t) { all.append(("tzeit", t)) }
                noon = c
            } else if let t = Solar.times(for: day, latitude: snapshot.latitude, longitude: snapshot.longitude) {
                all += [("dawn", t.dawn), ("sunrise", t.sunrise), ("chatzot", t.solarNoon), ("sunset", t.sunset)]
                noon = t.solarNoon
            }
            if let n = noon { all.append(("chatzotNight", n.addingTimeInterval(12 * 60 * 60))) }
        }
        return Array(all.filter { $0.date > now }.sorted { $0.date < $1.date }.prefix(5))
    }
    #endif
}
