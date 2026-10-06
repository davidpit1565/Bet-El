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
    let theme: String
    let lang: String
    let candleTime: Date?
    let candleLabel: String?
}

struct BetElCandleProvider: TimelineProvider {
    func placeholder(in context: Context) -> BetElCandleEntry {
        makeEntry(snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BetElCandleEntry) -> Void) {
        completion(makeEntry(snapshot: BetElSharedData.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BetElCandleEntry>) -> Void) {
        let snapshot = BetElSharedData.read()
        let entry = makeEntry(snapshot: snapshot)
        // Nothing more to compute locally once this week's candle time
        // has passed - the widget just keeps showing it until the app
        // itself reopens and syncs the next one. Reload right at that
        // moment anyway (harmless no-op) and again after a day as a
        // fallback in case the app is opened but the OS is slow to
        // deliver the reload signal.
        let now = Date()
        let fallback = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let reloadAfter = (entry.candleTime.map { $0 > now ? $0 : fallback }) ?? fallback
        completion(Timeline(entries: [entry], policy: .after(reloadAfter)))
    }

    private func makeEntry(snapshot: BetElSharedData.Snapshot) -> BetElCandleEntry {
        BetElCandleEntry(
            date: Date(),
            theme: snapshot.theme,
            lang: snapshot.lang,
            candleTime: snapshot.candleTime,
            candleLabel: snapshot.candleLabel
        )
    }
}

// MARK: - View

private struct BetElCandleWidgetView: View {
    let entry: BetElCandleEntry
    var body: some View {
        let palette = BetElTheme.palette(for: entry.theme)
        let align: HorizontalAlignment = WidgetL10n.isRTL(entry.lang) ? .trailing : .leading
        let fAlign: Alignment = WidgetL10n.isRTL(entry.lang) ? .trailing : .leading
        VStack(alignment: align, spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16))
                .foregroundColor(palette.gold)
                .frame(maxWidth: .infinity, alignment: fAlign)
            Spacer()
            Text(entry.candleLabel ?? WidgetL10n.t("candleLighting", lang: entry.lang))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(palette.inkSoft)
                .lineLimit(2)
                .multilineTextAlignment(WidgetL10n.isRTL(entry.lang) ? .trailing : .leading)
            Text(timeStr(entry.candleTime))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(palette.goldBright)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetBackground(palette: palette)
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
            BetElCandleWidgetView(entry: entry)
                .environment(\.layoutDirection, .leftToRight)
        }
        .configurationDisplayName("הַדְלָקַת נֵרוֹת")
        .description("זְמַן הַדְלָקַת הַנֵּרוֹת הַקָּרוֹב")
        .supportedFamilies([.systemSmall])
    }
}
