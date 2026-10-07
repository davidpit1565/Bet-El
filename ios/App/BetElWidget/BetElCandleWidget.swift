import WidgetKit
import SwiftUI

// MARK: - Entry / Provider

/// Small-only widget, its own kind (separate from BetElWidget's
/// small/medium/large one) - just the next candle-lighting time, per
/// the user's own request for "a small widget, only about candle
/// lighting". The time+label themselves are computed app-side (by
/// index.html's nextCandleLightingInfo(), which needs the full hebcal
/// library the widget extension can't run) and synced through the same
/// App Group snapshot as everything else - see SharedData.swift.
struct BetElCandleEntry: TimelineEntry {
    let date: Date
    var theme: String
    let lang: String
    let candleTime: Date?
    let candleLabel: String?
    /// Smart Stack: the candle widget jumps to the top of the stack in the hours before lighting.
    var relevance: TimelineEntryRelevance? = nil
}

struct BetElCandleProvider: TimelineProvider {
    private struct CandleRow: Decodable { let t: String; let l: String }

    func placeholder(in context: Context) -> BetElCandleEntry {
        makeEntry(snapshot: .placeholder, at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (BetElCandleEntry) -> Void) {
        completion(makeEntry(snapshot: BetElSharedData.read(), at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BetElCandleEntry>) -> Void) {
        let snapshot = BetElSharedData.read()
        let now = Date()
        let times = Self.candles(snapshot).map { $0.time }.filter { $0 > now }
        // one entry now, one a few hours before each coming lighting (so Smart Stack can raise
        // it) and one right after it (so the widget moves on to the next lighting by itself)
        var dates: [Date] = [now]
        for t in times.prefix(8) {
            dates.append(t.addingTimeInterval(-4 * 3600))
            dates.append(t.addingTimeInterval(60))
        }
        dates = Array(Set(dates.filter { $0 >= now })).sorted()
        let entries = dates.map { makeEntry(snapshot: snapshot, at: $0) }
        let fallback = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        completion(Timeline(entries: entries, policy: .after(dates.last ?? fallback)))
    }

    /// Every synced lighting, oldest first (falls back to the single legacy time).
    private static func candles(_ snapshot: BetElSharedData.Snapshot) -> [(time: Date, label: String)] {
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        if let json = snapshot.candlesJSON, let data = json.data(using: .utf8),
           let rows = try? JSONDecoder().decode([CandleRow].self, from: data), !rows.isEmpty {
            return rows.compactMap { r in
                guard let d = iso.date(from: r.t) ?? plain.date(from: r.t) else { return nil }
                return (d, r.l)
            }.sorted { $0.time < $1.time }
        }
        if let t = snapshot.candleTime { return [(t, snapshot.candleLabel ?? "")] }
        return []
    }

    private func makeEntry(snapshot: BetElSharedData.Snapshot, at date: Date) -> BetElCandleEntry {
        let next = Self.candles(snapshot).first(where: { $0.time > date })
        var entry = BetElCandleEntry(
            date: date,
            theme: snapshot.theme,
            lang: snapshot.lang,
            candleTime: next?.time,
            candleLabel: (next?.label.isEmpty == false) ? next?.label : snapshot.candleLabel
        )
        if let t = next?.time, t.timeIntervalSince(date) <= 4 * 3600 {
            entry.relevance = TimelineEntryRelevance(score: 100, duration: max(60, t.timeIntervalSince(date) + 1800))
        }
        return entry
    }
}

// MARK: - View

private struct BetElCandleWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: BetElCandleEntry
    var body: some View {
        Group {
            if #available(iOS 16.0, *), family == .accessoryRectangular {
                BetElCandleAccessoryRectangularView(entry: entry)
            } else {
                homeScreenBody
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .widgetURL(URL(string: "betel://calendar"))
        .widgetBackground(palette: BetElTheme.palette(for: entry.theme))
    }

    private var homeScreenBody: some View {
        let palette = BetElTheme.palette(for: entry.theme)
        let rtl = WidgetL10n.isRTL(entry.lang)
        let align: HorizontalAlignment = rtl ? .trailing : .leading
        let fAlign: Alignment = rtl ? .trailing : .leading
        let medium = family == .systemMedium
        let upcoming = (entry.candleTime.map { $0 > entry.date } ?? false)
        // no flame icon: the label, the big time and the day fill the whole widget
        return VStack(alignment: align, spacing: medium ? 6 : 4) {
            Spacer(minLength: 0)
            Text(entry.candleLabel ?? WidgetL10n.t("candleLighting", lang: entry.lang))
                .font(.system(size: medium ? 20 : 16, weight: .semibold))
                .foregroundColor(palette.inkSoft)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(rtl ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: fAlign)
            Text(timeStr(entry.candleTime))
                .font(.system(size: medium ? 76 : 50, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundColor(palette.goldBright)
                .lineLimit(1).minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: fAlign)
            // the day, not a countdown: "יום שישי" / "Friday"
            if upcoming, let c = entry.candleTime {
                Text(HebrewDay.weekdayText(c, lang: entry.lang))
                    .font(.system(size: medium ? 28 : 21, weight: .bold, design: .rounded))
                    .foregroundColor(palette.gold)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: fAlign)
            }
            Spacer(minLength: 0)
        }
        .padding(medium ? 16 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func timeStr(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

struct BetElCandleWidget: Widget {
    let kind: String = "BetElCandleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BetElCandleProvider()) { entry in
            SystemTheme { (theme: String) -> BetElCandleWidgetView in
                var e = entry
                e.theme = theme
                return BetElCandleWidgetView(entry: e)
            }
        }
        .configurationDisplayName("הַדְלָקַת נֵרוֹת")
        .description("זְמַן הַדְלָקַת הַנֵּרוֹת הַקָּרוֹב")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemSmall, .systemMedium]
        if #available(iOS 16.0, *) { families.append(.accessoryRectangular) }
        return families
    }
}
