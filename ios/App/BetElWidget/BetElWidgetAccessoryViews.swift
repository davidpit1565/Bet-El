import WidgetKit
import SwiftUI

/// Lock Screen / StandBy widget families (`.accessoryCircular`,
/// `.accessoryRectangular`), added alongside the existing Home Screen
/// small/medium/large families - these render in the system's own
/// monochrome/tinted Lock Screen style, which ignores custom background
/// colors entirely, so (unlike every other view in this target) these
/// deliberately use no palette colors at all and rely on `.widgetAccentable()`
/// to mark which elements should pick up the user's chosen tint.
///
/// `WidgetFamily.accessoryCircular`/`.accessoryRectangular` are iOS 16+ API
/// - this whole file is marked `@available(iOS 16.0, *)` so it compiles
/// against the iOS 26 SDK while the app's overall deployment target stays
/// at 15.0; `BetElWidget`/`BetElCandleWidget` only reach these views via an
/// `if #available(iOS 16.0, *)` branch (see their own `body`), and only
/// add the accessory family cases to `supportedFamilies` the same way, so
/// nothing here runs on an iOS 15 device - WidgetKit simply never offers
/// those families to add to its Lock Screen there.
/// Lock Screen circle: the day numeral big with the month under it ("כ״ו" / "תשרי").
@available(iOS 16.0, *)
struct BetElAccessoryCircularView: View {
    let entry: BetElEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(entry.dayText)
                    .font(.system(size: 22, weight: .heavy))
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(entry.monthText)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 4)
        }
        .widgetAccentable()
    }
}

/// Lock Screen rectangle: the full Hebrew date, then the parasha (or the holiday).
@available(iOS 16.0, *)
struct BetElAccessoryRectangularView: View {
    let entry: BetElEntry
    var body: some View {
        let isRTL = WidgetL10n.isRTL(entry.lang)
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 1) {
            Text(entry.hebrewDateText)
                .font(.system(size: 17, weight: .bold))
                .lineLimit(1).minimumScaleFactor(0.6)
                .multilineTextAlignment(isRTL ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
            if !entry.parashaText.isEmpty {
                Text(entry.parashaText)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .multilineTextAlignment(isRTL ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
        .widgetAccentable()
    }
}

/// Lock Screen inline (the single line above the clock): "כ״ו תשרי · פרשת בראשית".
@available(iOS 16.0, *)
struct BetElAccessoryInlineView: View {
    let entry: BetElEntry
    var body: some View {
        let line = entry.parashaText.isEmpty ? entry.hebrewDateText : "\(entry.hebrewDateText) · \(entry.parashaText)"
        Text(line)
    }
}

/// Tehillim on the Lock Screen: rectangle = "פרקי תהילים להיום" + the range, circle = the range.
@available(iOS 16.0, *)
struct BetElTehillimAccessoryRectangularView: View {
    let entry: BetElEntry
    var body: some View {
        let isRTL = WidgetL10n.isRTL(entry.lang)
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 1) {
            Text(WidgetL10n.t("tehillimToday", lang: entry.lang))
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
            Text(entry.tehillimRangeText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
        .widgetAccentable()
    }
}

@available(iOS 16.0, *)
struct BetElTehillimAccessoryCircularView: View {
    let entry: BetElEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            // just the chapters, centred
            Text(entry.tehillimRangeText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.4)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 5)
        }
        .widgetAccentable()
    }
}

/// Streak flame + count (was the old circular accessory).
@available(iOS 16.0, *)
struct BetElStreakAccessoryCircularView: View {
    let entry: BetElEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "flame.fill").font(.system(size: 13))
                Text("\(entry.streakCount)").font(.system(size: 15, weight: .bold))
            }
        }
        .widgetAccentable()
    }
}

@available(iOS 16.0, *)
struct BetElCandleAccessoryRectangularView: View {
    let entry: BetElCandleEntry
    var body: some View {
        let isRTL = WidgetL10n.isRTL(entry.lang)
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 1) {
            Text(entry.candleLabel ?? WidgetL10n.t("candleLighting", lang: entry.lang))
                .font(.system(size: 12))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
            Text(candleDayTime(entry))
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
        .widgetAccentable()
    }

    /// "יום שישי 18:20" - the day, then the time.
    private func candleDayTime(_ e: BetElCandleEntry) -> String {
        guard let d = e.candleTime else { return "--:--" }
        return "\(HebrewDay.weekdayText(d, lang: e.lang)) \(accessoryTimeString(d))"
    }

    private func accessoryTimeString(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}


// MARK: - Sun ring ("day until sunset", like Apple Weather's sunrise/sunset widget)

private func sunTimeString(_ d: Date?) -> String {
    guard let d = d else { return "--:--" }
    let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
}

/// Lock Screen circle: a ring that fills from sunrise to sunset (and from sunset to the next
/// sunrise at night); the centre shows the next sun time (sunset by day, sunrise at night).
@available(iOS 16.0, *)
struct BetElSunCircularView: View {
    let entry: BetElEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let a = entry.sunStart, let b = entry.sunEnd, b > a {
                ProgressView(timerInterval: a...b, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    VStack(spacing: 0) {
                        Image(systemName: entry.sunIsDay ? "sunset.fill" : "sunrise.fill").font(.system(size: 11))
                        Text(sunTimeString(b)).font(.system(size: 13, weight: .bold, design: .rounded)).minimumScaleFactor(0.6)
                    }
                }
                .progressViewStyle(.circular)
            } else {
                Image(systemName: "sun.max.fill")
            }
        }
        .widgetAccentable()
    }
}

/// Lock Screen rectangle: sunrise time, an arc with the sun on it, sunset time.
@available(iOS 16.0, *)
struct BetElSunRectangularView: View {
    let entry: BetElEntry
    var body: some View {
        let frac: Double = {
            guard entry.sunIsDay, let a = entry.sunStart, let b = entry.sunEnd, b > a else { return entry.sunIsDay ? 0 : 1 }
            return min(1, max(0, entry.date.timeIntervalSince(a) / b.timeIntervalSince(a)))
        }()
        VStack(spacing: 2) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    SunArc().stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 3])).opacity(0.5)
                    Circle().frame(width: 9, height: 9)
                        .position(x: w * CGFloat(frac), y: h - CGFloat(sin(Double.pi * frac)) * (h - 2) - 1)
                        .opacity(entry.sunIsDay ? 1 : 0.4)
                }
            }
            .frame(height: 26)
            HStack {
                Label(sunTimeString(entry.sunriseToday), systemImage: "sunrise.fill")
                Spacer()
                Label(sunTimeString(entry.sunsetToday), systemImage: "sunset.fill")
            }
            .font(.system(size: 12, weight: .semibold))
            .labelStyle(.titleAndIcon)
        }
        .environment(\.layoutDirection, .leftToRight)
        .widgetAccentable()
    }
}

private struct SunArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let steps = 40
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let pt = CGPoint(x: rect.width * CGFloat(t), y: rect.height - CGFloat(sin(Double.pi * t)) * (rect.height - 2) - 1)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

@available(iOS 16.0, *)
struct BetElSunLockWidget: Widget {
    let kind: String = "BetElSunLockWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BetElProvider()) { entry in
            BetElSunLockView(entry: entry)
        }
        .configurationDisplayName("עַד הַשְּׁקִיעָה")
        .description("כַּמָּה מֵהַיּוֹם עָבַר: זְרִיחָה וּשְׁקִיעָה")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

@available(iOS 16.0, *)
private struct BetElSunLockView: View {
    @Environment(\.widgetFamily) var family
    let entry: BetElEntry
    var body: some View {
        Group {
            if family == .accessoryCircular { BetElSunCircularView(entry: entry) }
            else { BetElSunRectangularView(entry: entry) }
        }
        .widgetBackground(palette: BetElTheme.palette(for: entry.theme))
    }
}
