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
            BetElCandleWidgetView(entry: entry)
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
