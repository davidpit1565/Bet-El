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

// MARK: - Small

private struct SmallWidgetView: View {
    let entry: BetElEntry
    var body: some View {
        let palette = BetElTheme.palette(for: entry.theme)
        let align = hAlign(entry.lang)
        VStack(alignment: align, spacing: 6) {
            HStack {
                if align == .leading { StreakBadge(count: entry.streakCount, palette: palette) }
                Spacer()
                if align == .trailing { StreakBadge(count: entry.streakCount, palette: palette) }
            }
            Spacer()
            Text(entry.hebrewDateText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(palette.ink)
                .multilineTextAlignment(textAlign(entry.lang))
                .lineLimit(2)
            if let t = entry.nextZmanTime {
                HStack(spacing: 4) {
                    Text(timeString(t)).font(.system(size: 12, weight: .bold))
                    Text(entry.nextZmanLabel).font(.system(size: 11))
                }
                .foregroundColor(palette.gold)
            }
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
        let align = hAlign(entry.lang)
        let fAlign = frameAlign(entry.lang)
        HStack(alignment: .top, spacing: 0) {
                VStack(alignment: align, spacing: 6) {
                    Text(entry.hebrewDateText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(palette.ink)
                        .multilineTextAlignment(textAlign(entry.lang))
                    if let t = entry.nextZmanTime {
                        HStack(spacing: 4) {
                            Text(timeString(t)).font(.system(size: 13, weight: .bold))
                            Text(entry.nextZmanLabel).font(.system(size: 12))
                        }
                        .foregroundColor(palette.gold)
                    }
                    Spacer()
                    StreakBadge(count: entry.streakCount, palette: palette)
                }
                .frame(maxWidth: .infinity, alignment: fAlign)

                GoldDivider(palette: palette).frame(width: 1).padding(.vertical, 4)

                VStack(alignment: align, spacing: 4) {
                    Text(WidgetL10n.t("tehillimToday", lang: entry.lang))
                        .font(.system(size: 11))
                        .foregroundColor(palette.inkSoft)
                    Text("\(entry.tehillimRange.start)\u{2013}\(entry.tehillimRange.end)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(palette.goldBright)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: fAlign)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Large

private struct LargeWidgetView: View {
    let entry: BetElEntry
    var body: some View {
        let palette = BetElTheme.palette(for: entry.theme)
        let align = hAlign(entry.lang)
        let fAlign = frameAlign(entry.lang)
        VStack(alignment: align, spacing: 10) {
                HStack {
                    if align == .leading { StreakBadge(count: entry.streakCount, palette: palette) }
                    Spacer()
                    if align == .trailing { StreakBadge(count: entry.streakCount, palette: palette) }
                }
                Text(entry.hebrewDateText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(palette.ink)
                    .frame(maxWidth: .infinity, alignment: fAlign)

                HStack(spacing: 16) {
                    if let t2 = entry.secondZmanTime, let l2 = entry.secondZmanLabel {
                        VStack(alignment: align, spacing: 2) {
                            Text(l2).font(.system(size: 11)).foregroundColor(palette.inkSoft)
                            Text(timeString(t2)).font(.system(size: 15, weight: .semibold)).foregroundColor(palette.gold)
                        }
                    }
                    VStack(alignment: align, spacing: 2) {
                        Text(entry.nextZmanLabel).font(.system(size: 11)).foregroundColor(palette.inkSoft)
                        Text(timeString(entry.nextZmanTime)).font(.system(size: 15, weight: .semibold)).foregroundColor(palette.gold)
                    }
                }
                .frame(maxWidth: .infinity, alignment: fAlign)

                GoldDivider(palette: palette)

                VStack(alignment: align, spacing: 4) {
                    Text(WidgetL10n.t("tehillimToday", lang: entry.lang))
                        .font(.system(size: 12))
                        .foregroundColor(palette.inkSoft)
                    Text("\(WidgetL10n.t("chapter", lang: entry.lang)) \(entry.tehillimRange.start)\u{2013}\(entry.tehillimRange.end)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(palette.goldBright)
                }
                .frame(maxWidth: .infinity, alignment: fAlign)

                Spacer()

                Text("\(entry.streakCount) \(WidgetL10n.t("dayStreak", lang: entry.lang))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(palette.gold)
                    .frame(maxWidth: .infinity, alignment: fAlign)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
        if #available(iOS 16.0, *) {
            families.append(contentsOf: [.accessoryCircular, .accessoryRectangular])
        }
        return families
    }
}
