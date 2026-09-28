import Foundation

/// Reads/writes the small JSON blob the main app pushes into the App
/// Group's shared UserDefaults suite, and that the widget's own
/// TimelineProvider reads back. Added to BOTH the main app target and
/// the BetElWidget extension target (see docs/widget-spec.md's "Data
/// sharing" section) - the main app writes via `BetElWidgetBridge`
/// (its own Capacitor plugin), the widget only ever reads.
enum BetElSharedData {
    static let appGroupId = "group.com.beitel.tehilim"
    private static let key = "betel_widget_data"

    struct Snapshot: Codable {
        var streakCount: Int
        var streakBest: Int
        /// "dark" or "light" - mirrors the app's own S.theme setting
        /// (Settings > appearance), not the iPhone's system appearance.
        var theme: String
        /// Mirrors the app's own LOC.lat/LOC.lon (zmanim location) -
        /// falls back to the app's own FALLBACK location (Antwerp) if
        /// the app hasn't shared a real one yet.
        var latitude: Double
        var longitude: Double

        static let placeholder = Snapshot(
            streakCount: 0, streakBest: 0, theme: "dark",
            latitude: 51.2194, longitude: 4.4025
        )
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    /// Called by BetElWidgetBridge (main app target only).
    static func write(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    /// Called by the widget's Provider (widget extension target only).
    /// Falls back to `.placeholder` if the app hasn't written anything
    /// yet (e.g. right after install, before the app has ever opened).
    static func read() -> Snapshot {
        guard let data = defaults?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }
}
