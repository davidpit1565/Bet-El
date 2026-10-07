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
        /// Mirrors the app's own S.lang setting ("he"/"en"/"fr"/"ru"/"ka").
        /// Widget copy is only localized for "he" and "en" so far
        /// (see Localization.swift) - any other value falls back to "he".
        var lang: String
        /// Mirrors the app's own LOC.lat/LOC.lon (zmanim location) -
        /// falls back to the app's own FALLBACK location (Antwerp) if
        /// the app hasn't shared a real one yet.
        var latitude: Double
        var longitude: Double
        /// ISO-8601 time of the next candle lighting (Shabbat or Yom
        /// Tov, whichever comes first) as computed by the app's own
        /// `shabbatTimes()`/`nextCandleLightingInfo()` - nil if the app
        /// hasn't synced yet. Decoded to a Date by the reader below.
        var candleTimeISO: String?
        /// Hebrew label for that occasion (e.g. "ערב שבת קדש", a Yom
        /// Tov's own name, or "חנוכה · נר X") - already in the app's
        /// current UI language's script where applicable (it's Hebrew
        /// text either way, same as the home-screen banner it mirrors).
        var candleLabel: String?
        /// JSON `[{"d":"2026-10-07","t":"פרשת בראשית"},...]` for the next ~2 weeks,
        /// built by the app (hebcal): the holiday on that day, else the coming
        /// Shabbat's parasha. The widget can't compute either, so it just looks up today.
        var dayLabelsJSON: String?

        static let placeholder = Snapshot(
            streakCount: 0, streakBest: 0, theme: "dark", lang: "he",
            latitude: 51.2194, longitude: 4.4025,
            candleTimeISO: nil, candleLabel: nil, dayLabelsJSON: nil
        )

        /// Parasha / holiday text for `date` ("" until the app has synced, or past the synced range).
        func dayLabel(for date: Date) -> String {
            guard let json = dayLabelsJSON, let data = json.data(using: .utf8),
                  let rows = try? JSONDecoder().decode([DayLabel].self, from: data) else { return "" }
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            let key = f.string(from: date)
            return rows.first(where: { $0.d == key })?.t ?? ""
        }

        private struct DayLabel: Codable { let d: String; let t: String }

        var candleTime: Date? {
            guard let iso = candleTimeISO else { return nil }
            return ISO8601DateFormatter().date(from: iso)
        }
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
