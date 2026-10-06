import WidgetKit
import Foundation

struct BetElEntry: TimelineEntry {
    let date: Date
    let hebrewDateText: String
    let tehillimRange: (start: Int, end: Int)
    let nextZmanLabel: String
    let nextZmanTime: Date?
    let secondZmanLabel: String?
    let secondZmanTime: Date?
    let streakCount: Int
    let theme: String
    /// Mirrors the app's own S.lang ("he"/"en"/"fr"/"ru"/"ka") - see
    /// WidgetL10n for which languages the widget's own chrome text
    /// actually has a translation for.
    let lang: String
    let candleTime: Date?
    let candleLabel: String?

    /// A stable deep link into the app for whatever this entry is
    /// currently showing - opens straight to today's Tehillim portion.
    var deepLinkURL: URL? {
        URL(string: "betel://tehillim/\(tehillimRange.start)")
    }
}

struct BetElProvider: TimelineProvider {
    func placeholder(in context: Context) -> BetElEntry {
        makeEntry(for: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BetElEntry) -> Void) {
        let snapshot = BetElSharedData.read()
        completion(makeEntry(for: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BetElEntry>) -> Void) {
        let snapshot = BetElSharedData.read()
        let now = Date()
        var entries: [BetElEntry] = []

        // One entry per zman today (so "next zman" advances through the
        // day) plus one for right now, deduplicated and sorted.
        var refreshDates: [Date] = [now]
        if let times = Solar.times(for: now, latitude: snapshot.latitude, longitude: snapshot.longitude) {
            refreshDates.append(contentsOf: [times.dawn, times.sunrise, times.solarNoon, times.sunset])
        }
        // Also refresh right after local midnight, for the next day's
        // Hebrew date + Tehillim portion + a fresh zmanim set.
        let cal = Calendar.current
        if let midnight = cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 1), matchingPolicy: .nextTime) {
            refreshDates.append(midnight)
        }

        refreshDates = refreshDates.filter { $0 > now }.sorted()
        entries.append(makeEntry(for: now, snapshot: snapshot))
        for d in refreshDates {
            entries.append(makeEntry(for: d, snapshot: snapshot))
        }

        let reloadAfter = refreshDates.last ?? cal.date(byAdding: .hour, value: 6, to: now)!
        completion(Timeline(entries: entries, policy: .after(reloadAfter)))
    }

    private func makeEntry(for date: Date, snapshot: BetElSharedData.Snapshot) -> BetElEntry {
        let lang = snapshot.lang
        let portion = HebrewDay.tehillimPortion(for: date)
        let times = Solar.times(for: date, latitude: snapshot.latitude, longitude: snapshot.longitude)

        let dawnLabel = WidgetL10n.t("dawn", lang: lang)
        let sunriseLabel = WidgetL10n.t("sunrise", lang: lang)
        let sunsetLabel = WidgetL10n.t("sunset", lang: lang)
        var nextLabel = dawnLabel
        var nextTime: Date? = times?.dawn
        var secondLabel: String? = sunriseLabel
        var secondTime: Date? = times?.sunrise

        if let times = times {
            if date < times.dawn {
                nextLabel = dawnLabel; nextTime = times.dawn
                secondLabel = sunriseLabel; secondTime = times.sunrise
            } else if date < times.sunrise {
                nextLabel = sunriseLabel; nextTime = times.sunrise
                secondLabel = sunsetLabel; secondTime = times.sunset
            } else if date < times.sunset {
                nextLabel = sunsetLabel; nextTime = times.sunset
                secondLabel = nil; secondTime = nil
            } else {
                // after sunset - show tomorrow's dawn as "next"
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
                let tTimes = Solar.times(for: tomorrow, latitude: snapshot.latitude, longitude: snapshot.longitude)
                nextLabel = dawnLabel; nextTime = tTimes?.dawn
                secondLabel = tTimes != nil ? sunriseLabel : nil
                secondTime = tTimes?.sunrise
            }
        }

        return BetElEntry(
            date: date,
            hebrewDateText: HebrewDay.formatted(date, lang: lang),
            tehillimRange: portion,
            nextZmanLabel: nextLabel,
            nextZmanTime: nextTime,
            secondZmanLabel: secondLabel,
            secondZmanTime: secondTime,
            streakCount: snapshot.streakCount,
            theme: snapshot.theme,
            lang: lang,
            candleTime: snapshot.candleTime,
            candleLabel: snapshot.candleLabel
        )
    }
}
