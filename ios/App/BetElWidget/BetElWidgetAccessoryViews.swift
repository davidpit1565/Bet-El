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
@available(iOS 16.0, *)
struct BetElAccessoryCircularView: View {
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
struct BetElAccessoryRectangularView: View {
    let entry: BetElEntry
    var body: some View {
        let isRTL = WidgetL10n.isRTL(entry.lang)
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 1) {
            Text(entry.hebrewDateText)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text("\(WidgetL10n.t("tehillimToday", lang: entry.lang)) \(entry.tehillimRangeText)")
                .font(.system(size: 12))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
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
            Text(accessoryTimeString(entry.candleTime))
                .font(.system(size: 15, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
        .widgetAccentable()
    }

    private func accessoryTimeString(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
