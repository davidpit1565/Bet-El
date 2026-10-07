import WidgetKit
import SwiftUI

// MARK: - Design tokens (mirrors design-system/beit-el-design-system.css)

enum BetElTheme {
    struct Palette {
        let bgTop: Color
        let bgBottom: Color
        let ink: Color
        let inkSoft: Color
        let gold: Color
        let goldBright: Color
        let line: Color
    }

    static func palette(for theme: String) -> Palette {
        if theme == "light" {
            return Palette(
                bgTop: Color(red: 0.984, green: 0.961, blue: 0.902),   // #fbf5e6
                bgBottom: Color(red: 0.906, green: 0.863, blue: 0.761), // #e7dcc2
                ink: Color(red: 0.133, green: 0.192, blue: 0.306),      // #22314e
                inkSoft: Color(red: 0.235, green: 0.290, blue: 0.400),  // #3c4a66
                gold: Color(red: 0.604, green: 0.459, blue: 0.149),     // #9a7526
                goldBright: Color(red: 0.776, green: 0.604, blue: 0.235),// #c69a3c
                line: Color(red: 0.588, green: 0.455, blue: 0.173, opacity: 0.32)
            )
        }
        return Palette(
            bgTop: Color(red: 0.086, green: 0.133, blue: 0.290),   // #16224a
            bgBottom: Color(red: 0.027, green: 0.043, blue: 0.086), // #070b16
            ink: Color(red: 0.965, green: 0.945, blue: 0.894),      // #f6f1e4
            inkSoft: Color(red: 0.804, green: 0.839, blue: 0.925),  // #cdd6ec
            gold: Color(red: 0.831, green: 0.686, blue: 0.373),     // #d4af5f
            goldBright: Color(red: 0.953, green: 0.890, blue: 0.686),// #f3e3af
            line: Color(red: 0.831, green: 0.686, blue: 0.373, opacity: 0.35)
        )
    }
}

private func timeString(_ date: Date?) -> String {
    guard let date = date else { return "--:--" }
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: date)
}

/// Text/frame alignment for the given app language - widget layout is
/// always forced to `.leftToRight` (see BetElWidgetEntryView) so this
/// is what actually decides which side content hugs: `.trailing`
/// (right) for Hebrew and any not-yet-translated language (its text is
/// still Hebrew via WidgetL10n's fallback), `.leading` (left) for
/// English, matching each script's natural reading direction.
private func hAlign(_ lang: String) -> HorizontalAlignment {
    WidgetL10n.isRTL(lang) ? .trailing : .leading
}
private func frameAlign(_ lang: String) -> Alignment {
    WidgetL10n.isRTL(lang) ? .trailing : .leading
}
private func textAlign(_ lang: String) -> TextAlignment {
    WidgetL10n.isRTL(lang) ? .trailing : .leading
}

// MARK: - Shared pieces

private struct BackgroundView: View {
    let palette: BetElTheme.Palette
    var body: some View {
        LinearGradient(
            colors: [palette.bgTop, palette.bgBottom],
            startPoint: .top, endPoint: .bottom
        )
    }
}

private struct GoldDivider: View {
    let palette: BetElTheme.Palette
    var body: some View {
        Rectangle().fill(palette.line).frame(height: 1)
    }
}

private struct StreakBadge: View {
    let count: Int
    let palette: BetElTheme.Palette
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill").font(.system(size: 10))
            Text("\(count)").font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(palette.gold)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(palette.gold.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Building blocks

/// A live, system-ticking countdown ("5:26:00") to `target` - driven by
/// `Text(_, style: .timer)`, so it keeps counting down on the Home/Lock
/// Screen on its own with no extra timeline entries.
private struct Countdown: View {
    let target: Date?
    let from: Date
    let size: CGFloat
    let color: Color
    var body: some View {
        if let t = target, t > from {
            Text(t, style: .timer)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else {
            Text("--:--")
                .font(.system(size: size, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
}

/// [leading content][Spacer][trailing content], flipped for Hebrew so the
/// label hugs the right edge - the whole widget is laid out left-to-right
/// (see BetElWidgetEntryView), so "which side" is decided here.
private struct SideRow<L: View, R: View>: View {
    let lang: String
    let label: L
    let value: R
    init(lang: String, @ViewBuilder label: () -> L, @ViewBuilder value: () -> R) {
        self.lang = lang; self.label = label(); self.value = value()
    }
    var body: some View {
        HStack(spacing: 8) {
            if WidgetL10n.isRTL(lang) { value; Spacer(minLength: 4); label }
            else { label; Spacer(minLength: 4); value }
        }
    }
}

private func firstUpcoming(_ rows: [ZmanRow], after date: Date) -> String? {
    rows.first(where: { $0.time > date })?.key
}

/// The big date: weekday, then the day numeral large, then month + year.
private struct DateBlock: View {
    let entry: BetElEntry
    let palette: BetElTheme.Palette
    let daySize: CGFloat
    let showWeekday: Bool
    /// One line: big day numeral beside "month year" (used by the Large widget,
    /// which is otherwise too tall for its 354pt).
    var compact: Bool = false
    var body: some View {
        let align = hAlign(entry.lang)
        if compact {
            let day = Text(entry.dayText)
                .font(.system(size: daySize, weight: .heavy))
                .foregroundColor(palette.goldBright)
                .lineLimit(1).minimumScaleFactor(0.5)
            let rest = Text("\(entry.monthText) \(entry.yearText)")
                .font(.system(size: max(16, daySize * 0.42), weight: .semibold))
                .foregroundColor(palette.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                if WidgetL10n.isRTL(entry.lang) { rest; day } else { day; rest }
            }
            .frame(maxWidth: .infinity, alignment: frameAlign(entry.lang))
        } else {
        VStack(alignment: align, spacing: 0) {
            if showWeekday {
                Text(entry.weekdayText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(palette.inkSoft)
            }
            Text(entry.dayText)
                .font(.system(size: daySize, weight: .heavy))
                .foregroundColor(palette.goldBright)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text("\(entry.monthText) \(entry.yearText)")
                .font(.system(size: max(15, daySize * 0.4), weight: .semibold))
                .foregroundColor(palette.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: frameAlign(entry.lang))
        }
    }
}

/// Next zman: caption, its name, a live countdown and the clock time.
private struct NextZmanBlock: View {
    let entry: BetElEntry
    let palette: BetElTheme.Palette
    let countdownSize: CGFloat
    var showTime: Bool = true
    var body: some View {
        let align = hAlign(entry.lang)
        VStack(alignment: align, spacing: 1) {
            Text(entry.nextZmanLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(palette.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            Countdown(target: entry.nextZmanTime, from: entry.date, size: countdownSize, color: palette.gold)
            if showTime, let t = entry.nextZmanTime {
                Text(timeString(t))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlign(entry.lang))
    }
}

private struct TehillimLine: View {
    let entry: BetElEntry
    let palette: BetElTheme.Palette
    let size: CGFloat
    var body: some View {
        SideRow(lang: entry.lang, label: {
            Text(WidgetL10n.t("tehillimToday", lang: entry.lang))
                .font(.system(size: size - 3, weight: .medium)).foregroundColor(palette.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.6)
        }, value: {
            Text("\(entry.tehillimRangeText)")
                .font(.system(size: size + 2, weight: .bold, design: .rounded)).foregroundColor(palette.goldBright)
                .lineLimit(1).minimumScaleFactor(0.5)
        })
    }
}

// MARK: - Small

private struct SmallWidgetView: View {
    let entry: BetElEntry
    var body: some View {
        let palette = BetElTheme.palette(for: entry.theme)
        VStack(alignment: hAlign(entry.lang), spacing: 4) {
            SideRow(lang: entry.lang, label: {
                Text(entry.weekdayText).font(.system(size: 12, weight: .semibold)).foregroundColor(palette.inkSoft)
            }, value: { StreakBadge(count: entry.streakCount, palette: palette) })
            DateBlock(entry: entry, palette: palette, daySize: 42, showWeekday: false)
            Spacer(minLength: 2)
            GoldDivider(palette: palette)
            NextZmanBlock(entry: entry, palette: palette, countdownSize: 22)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Medium

private struct MediumWidgetView: View {
    let entry: BetElEntry
    var body: some View {
        let palette = BetElTheme.palette(for: entry.theme)
        HStack(alignment: .center, spacing: 12) {
            if WidgetL10n.isRTL(entry.lang) { right(palette); GoldDivider(palette: palette).frame(width: 1).padding(.vertical, 6); left(palette) }
            else { left(palette); GoldDivider(palette: palette).frame(width: 1).padding(.vertical, 6); right(palette) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // "left"/"right" are just the two columns: the date, and the live info
    private func left(_ palette: BetElTheme.Palette) -> some View {
        VStack(alignment: hAlign(entry.lang), spacing: 4) {
            DateBlock(entry: entry, palette: palette, daySize: 48, showWeekday: true)
            Spacer(minLength: 0)
            StreakBadge(count: entry.streakCount, palette: palette)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlign(entry.lang))
    }

    private func right(_ palette: BetElTheme.Palette) -> some View {
        VStack(alignment: hAlign(entry.lang), spacing: 6) {
            NextZmanBlock(entry: entry, palette: palette, countdownSize: 30)
            Spacer(minLength: 0)
            GoldDivider(palette: palette)
            TehillimLine(entry: entry, palette: palette, size: 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlign(entry.lang))
    }
}

// MARK: - Large

private struct LargeWidgetView: View {
    let entry: BetElEntry
    var body: some View {
        let palette = BetElTheme.palette(for: entry.theme)
        let upcoming = firstUpcoming(entry.zmanimToday, after: entry.date)
        VStack(alignment: hAlign(entry.lang), spacing: 6) {
            SideRow(lang: entry.lang, label: {
                Text(entry.weekdayText).font(.system(size: 14, weight: .semibold)).foregroundColor(palette.inkSoft)
            }, value: { StreakBadge(count: entry.streakCount, palette: palette) })

            DateBlock(entry: entry, palette: palette, daySize: 42, showWeekday: false, compact: true)

            // next zman, as a card
            NextZmanBlock(entry: entry, palette: palette, countdownSize: 32, showTime: false)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(palette.gold.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 4) {
                ForEach(entry.zmanimToday) { row in
                    let isNext = row.key == upcoming
                    SideRow(lang: entry.lang, label: {
                        Text(row.label)
                            .font(.system(size: 14, weight: isNext ? .bold : .medium))
                            .foregroundColor(isNext ? palette.goldBright : palette.ink)
                    }, value: {
                        Text(timeString(row.time))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(isNext ? palette.goldBright : palette.gold)
                    })
                }
            }

            Spacer(minLength: 0)
            GoldDivider(palette: palette)
            HStack(spacing: 10) {
                if WidgetL10n.isRTL(entry.lang) { candleCell(palette); tehillimCell(palette) }
                else { tehillimCell(palette); candleCell(palette) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tehillimCell(_ palette: BetElTheme.Palette) -> some View {
        VStack(alignment: hAlign(entry.lang), spacing: 1) {
            Text(WidgetL10n.t("tehillimToday", lang: entry.lang)).font(.system(size: 11)).foregroundColor(palette.inkSoft).lineLimit(1).minimumScaleFactor(0.6)
            Text("\(entry.tehillimRangeText)")
                .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(palette.goldBright)
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: frameAlign(entry.lang))
    }

    @ViewBuilder
    private func candleCell(_ palette: BetElTheme.Palette) -> some View {
        VStack(alignment: hAlign(entry.lang), spacing: 1) {
            Text(entry.candleLabel ?? WidgetL10n.t("candleLighting", lang: entry.lang))
                .font(.system(size: 11)).foregroundColor(palette.inkSoft).lineLimit(1).minimumScaleFactor(0.7)
            if let c = entry.candleTime, c > entry.date {
                // "יום שישי 18:20" - the day and hour, not a countdown
                Text("\(HebrewDay.weekdayText(c, lang: entry.lang)) \(timeString(c))")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(palette.goldBright)
                    .lineLimit(1).minimumScaleFactor(0.6)
            } else {
                Text(WidgetL10n.t("noCandle", lang: entry.lang))
                    .font(.system(size: 12, weight: .medium)).foregroundColor(palette.inkSoft).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlign(entry.lang))
    }
}

// MARK: - Zmanim widget (today's four times, next one live)

private struct ZmanimWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: BetElEntry
    var body: some View {
        let palette = BetElTheme.palette(for: entry.theme)
        let upcoming = firstUpcoming(entry.zmanimToday, after: entry.date)
        Group {
            if #available(iOS 16.0, *), family == .accessoryRectangular {
                BetElZmanAccessoryView(entry: entry)
            } else if family == .systemSmall {
                VStack(alignment: hAlign(entry.lang), spacing: 5) {
                    ForEach(entry.zmanimToday) { row in
                        let isNext = row.key == upcoming
                        SideRow(lang: entry.lang, label: {
                            Text(row.label).font(.system(size: 13, weight: isNext ? .bold : .medium))
                                .foregroundColor(isNext ? palette.goldBright : palette.ink)
                                .lineLimit(1).minimumScaleFactor(0.6)
                        }, value: {
                            Text(timeString(row.time)).font(.system(size: 15, weight: .bold, design: .rounded)).monospacedDigit()
                                .foregroundColor(isNext ? palette.goldBright : palette.gold)
                        })
                    }
                    Spacer(minLength: 0)
                    GoldDivider(palette: palette)
                    Countdown(target: entry.nextZmanTime, from: entry.date, size: 22, color: palette.goldBright)
                        .frame(maxWidth: .infinity, alignment: frameAlign(entry.lang))
                }
                .padding(12)
            } else {
                // medium: countdown beside a 2x2 grid; large: countdown on top, grid below
                let isLarge = family == .systemLarge
                let grid = LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(entry.zmanimToday) { row in
                        let isNext = row.key == upcoming
                        VStack(spacing: 1) {
                            Text(row.label).font(.system(size: 11, weight: .medium)).foregroundColor(palette.inkSoft)
                                .lineLimit(1).minimumScaleFactor(0.6)
                            Text(timeString(row.time))
                                .font(.system(size: isLarge ? 26 : 18, weight: .bold, design: .rounded)).monospacedDigit()
                                .foregroundColor(isNext ? palette.goldBright : palette.gold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isLarge ? 14 : 5)
                        .background(palette.gold.opacity(isNext ? 0.22 : 0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                if isLarge {
                    VStack(alignment: hAlign(entry.lang), spacing: 10) {
                        NextZmanBlock(entry: entry, palette: palette, countdownSize: 46)
                        grid
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                } else {
                    HStack(alignment: .center, spacing: 10) {
                        if WidgetL10n.isRTL(entry.lang) { grid; NextZmanBlock(entry: entry, palette: palette, countdownSize: 28) }
                        else { NextZmanBlock(entry: entry, palette: palette, countdownSize: 28); grid }
                    }
                    .padding(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.layoutDirection, .leftToRight)
        .widgetURL(entry.deepLinkURL)
        .widgetBackground(palette: palette)
    }
}

@available(iOS 16.0, *)
private struct BetElZmanAccessoryView: View {
    let entry: BetElEntry
    var body: some View {
        let isRTL = WidgetL10n.isRTL(entry.lang)
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 1) {
            Text(entry.nextZmanLabel).font(.system(size: 12)).lineLimit(1)
            if let t = entry.nextZmanTime, t > entry.date {
                Text(t, style: .timer).font(.system(size: 17, weight: .bold)).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
        .widgetAccentable()
    }
}

struct BetElZmanimWidget: Widget {
    let kind: String = "BetElZmanimWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BetElProvider()) { entry in
            ZmanimWidgetView(entry: entry)
        }
        .configurationDisplayName("זְמַנֵּי הַיּוֹם")
        .description("עֲלוֹת הַשַּׁחַר, זְרִיחָה, חֲצוֹת וּשְׁקִיעָה, עִם סְפִירָה לַאֲחוֹרָה")
        .supportedFamilies(Self.families)
    }
    private static var families: [WidgetFamily] {
        var f: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
        if #available(iOS 16.0, *) { f.append(.accessoryRectangular) }
        return f
    }
}

// MARK: - Tehillim widget (today's portion, big)

private struct TehillimWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: BetElEntry
    var body: some View {
        if #available(iOS 16.0, *), family == .accessoryRectangular {
            BetElTehillimAccessoryRectangularView(entry: entry)
                .environment(\.layoutDirection, .leftToRight)
                .widgetURL(entry.deepLinkURL).widgetBackground(palette: BetElTheme.palette(for: entry.theme))
        } else if #available(iOS 16.0, *), family == .accessoryCircular {
            BetElTehillimAccessoryCircularView(entry: entry)
                .widgetURL(entry.deepLinkURL).widgetBackground(palette: BetElTheme.palette(for: entry.theme))
        } else {
            homeBody
        }
    }

    private var homeBody: some View {
        let palette = BetElTheme.palette(for: entry.theme)
        return VStack(alignment: hAlign(entry.lang), spacing: 4) {
            Text(WidgetL10n.t("tehillimToday", lang: entry.lang))
                .font(.system(size: family == .systemSmall ? 14 : 17, weight: .semibold))
                .foregroundColor(palette.inkSoft)
                .lineLimit(2).minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: frameAlign(entry.lang))
            Spacer(minLength: 0)
            Text("\(entry.tehillimRangeText)")
                .font(.system(size: family == .systemSmall ? 30 : 46, weight: .heavy, design: .rounded))
                .foregroundColor(palette.goldBright)
                .lineLimit(1).minimumScaleFactor(0.3)
                .frame(maxWidth: .infinity, alignment: frameAlign(entry.lang))
            Spacer(minLength: 0)
            SideRow(lang: entry.lang, label: {
                Text("\(entry.dayText) \(entry.monthText)").font(.system(size: 13, weight: .medium)).foregroundColor(palette.inkSoft)
            }, value: { StreakBadge(count: entry.streakCount, palette: palette) })
        }
        .padding(family == .systemSmall ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlign(entry.lang))
        .environment(\.layoutDirection, .leftToRight)
        .widgetURL(entry.deepLinkURL)
        .widgetBackground(palette: palette)
    }
}

struct BetElTehillimWidget: Widget {
    let kind: String = "BetElTehillimWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BetElProvider()) { entry in
            TehillimWidgetView(entry: entry)
        }
        .configurationDisplayName("תְּהִלִּים הַיּוֹם")
        .description("הַפְּרָקִים שֶׁל הַיּוֹם בְּגוֹדֶל גָּדוֹל, לִלְחִיצָה וּפְתִיחָה")
        .supportedFamilies(Self.families)
    }
    private static var families: [WidgetFamily] {
        var f: [WidgetFamily] = [.systemSmall, .systemMedium]
        if #available(iOS 16.0, *) { f.append(contentsOf: [.accessoryRectangular, .accessoryCircular]) }
        return f
    }
}

// MARK: - Streak widget

private struct StreakWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: BetElEntry
    var body: some View {
        if #available(iOS 16.0, *), family == .accessoryCircular {
            BetElStreakAccessoryCircularView(entry: entry)
                .widgetURL(entry.deepLinkURL).widgetBackground(palette: BetElTheme.palette(for: entry.theme))
        } else {
            homeBody
        }
    }

    private var homeBody: some View {
        let palette = BetElTheme.palette(for: entry.theme)
        let big: CGFloat = family == .systemSmall ? 64 : 80
        return VStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: family == .systemSmall ? 30 : 36))
                .foregroundColor(palette.gold)
            Text("\(entry.streakCount)")
                .font(.system(size: big, weight: .heavy, design: .rounded))
                .foregroundColor(palette.goldBright)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(WidgetL10n.t("dayStreak", lang: entry.lang))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(palette.ink)
            Text("\(WidgetL10n.t("best", lang: entry.lang)): \(entry.streakBest)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(palette.inkSoft)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.layoutDirection, .leftToRight)
        .widgetURL(entry.deepLinkURL)
        .widgetBackground(palette: palette)
    }
}

struct BetElStreakWidget: Widget {
    let kind: String = "BetElStreakWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BetElProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("רֶצֶף לִמּוּד")
        .description("כַּמָּה יָמִים בְּרֶצֶף לָמַדְתָּ")
        .supportedFamilies(Self.families)
    }
    private static var families: [WidgetFamily] {
        var f: [WidgetFamily] = [.systemSmall]
        if #available(iOS 16.0, *) { f.append(.accessoryCircular) }
        return f
    }
}

// MARK: - Entry view (family switch)

struct BetElWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: BetElEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            case .systemSmall:
                SmallWidgetView(entry: entry)
            default:
                // Only reachable for .accessoryCircular/.accessoryRectangular
                // (iOS 16+) - see BetElWidget.supportedFamilies below, which
                // only ever offers those families on iOS 16+ in the first
                // place, so this branch is never hit pre-16 despite the
                // `if #available` looking redundant here.
                if #available(iOS 16.0, *), family == .accessoryCircular {
                    BetElAccessoryCircularView(entry: entry)
                } else if #available(iOS 16.0, *), family == .accessoryRectangular {
                    BetElAccessoryRectangularView(entry: entry)
                } else {
                    SmallWidgetView(entry: entry)
                }
            }
        }
        // Widget copy always follows the app's own S.lang setting, not
        // the device's system language - so layout direction is forced
        // explicitly here rather than left to inherit from the OS
        // locale (which the widget extension would otherwise pick up).
        .environment(\.layoutDirection, .leftToRight)
        .widgetURL(entry.deepLinkURL)
        .widgetBackground(palette: BetElTheme.palette(for: entry.theme))
    }
}

extension View {
    /// `.containerBackground(for: .widget)` (iOS 17+) is what lets the
    /// system render this widget's background as part of the real
    /// tinted/"Liquid Glass" Home Screen appearance modes the user can
    /// pick in the widget editor - a plain `.background()` behind the
    /// content (the old approach every view here used) opts out of that
    /// entirely and always shows this flat gradient regardless of what
    /// appearance the user chose. Falls back to the old plain background
    /// below iOS 17 (this extension's own deployment target), where
    /// `containerBackground` doesn't exist at all.
    @ViewBuilder
    func widgetBackground(palette: BetElTheme.Palette) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                BackgroundView(palette: palette)
            }
        } else {
            self.background(BackgroundView(palette: palette))
        }
    }
}

struct BetElWidget: Widget {
    let kind: String = "BetElWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BetElProvider()) { entry in
            BetElWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("תָּמִיד")
        .description("תַּאֲרִיךְ עִבְרִי, תְּהִלִּים הַיּוֹם וְהִתְקַדְּמוּתְךָ")
        .supportedFamilies(Self.families)
    }

    /// `.accessoryCircular`/`.accessoryRectangular` (Lock Screen) only
    /// exist from iOS 16 - appended conditionally rather than raising this
    /// extension's own deployment target, so the Home Screen families keep
    /// working unchanged all the way back to iOS 15.
    private static var families: [WidgetFamily] {
        // Lock Screen families now live in the dedicated widgets below
        // (BetElDateLockWidget, Tehillim, Streak) so each has its own gallery entry.
        [.systemSmall, .systemMedium, .systemLarge]
    }
}

/// Lock Screen date: rectangle (date + parasha/holiday), circle (day + month), inline.
@available(iOS 16.0, *)
struct BetElDateLockWidget: Widget {
    let kind: String = "BetElDateLockWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BetElProvider()) { entry in
            BetElDateLockView(entry: entry)
        }
        .configurationDisplayName("תַּאֲרִיךְ עִבְרִי")
        .description("הַתַּאֲרִיךְ הָעִבְרִי, הַפָּרָשָׁה אוֹ הֶחָג")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

@available(iOS 16.0, *)
private struct BetElDateLockView: View {
    @Environment(\.widgetFamily) var family
    let entry: BetElEntry
    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: BetElAccessoryCircularView(entry: entry)
            case .accessoryInline: BetElAccessoryInlineView(entry: entry)
            default: BetElAccessoryRectangularView(entry: entry)
            }
        }
        .environment(\.layoutDirection, .leftToRight)   // so "trailing" is always the physical right
        .widgetURL(entry.deepLinkURL)
        .widgetBackground(palette: BetElTheme.palette(for: entry.theme))
    }
}
