import WidgetKit
import Foundation

struct ZmanRow: Identifiable {
    let key: String
    let label: String
    let time: Date
    var id: String { key }
}

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
    let streakBest: Int
    /// The Hebrew date split into parts so each widget size can lay it out
    /// big: weekday ("יום רביעי"), day ("כ״ו"), month ("תשרי"), year ("תשפ״ז")
    /// - in English the same parts as numerals/English names.
    let weekdayText: String
    let dayText: String
    let monthText: String
    let yearText: String
    /// Today's dawn / sunrise / midday / sunset, in order, for the widgets
    /// that list them.
    let zmanimToday: [ZmanRow]

    /// "א׳–ו׳" in Hebrew (letters, never digits), "1\u{2013}6" in every other language.
    var tehillimRangeText: String {
        let (a, b) = (tehillimRange.start, tehillimRange.end)
        // letters only, with air around a single dash: "מב – עב" (start on the right).
        // U+2067/U+2069 isolate it as right-to-left inside the forced-LTR widget layout.
        if lang == "he" { return "\u{2067}\(HebrewDay.gematriaPlain(a)) \u{2013} \(HebrewDay.gematriaPlain(b))\u{2069}" }
        return "\(a)\u{2013}\(b)"
    }

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

    private static func zmanimRows(_ times: Solar.DayTimes?, lang: String) -> [ZmanRow] {
        guard let t = times else { return [] }
        return [
            ZmanRow(key: "dawn", label: WidgetL10n.t("dawn", lang: lang), time: t.dawn),
            ZmanRow(key: "sunrise", label: WidgetL10n.t("sunrise", lang: lang), time: t.sunrise),
            ZmanRow(key: "chatzot", label: WidgetL10n.t("chatzot", lang: lang), time: t.solarNoon),
            ZmanRow(key: "sunset", label: WidgetL10n.t("sunset", lang: lang), time: t.sunset),
        ]
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
            candleLabel: snapshot.candleLabel,
            streakBest: snapshot.streakBest,
            weekdayText: HebrewDay.weekdayText(date, lang: lang),
            dayText: HebrewDay.dayText(date, lang: lang),
            monthText: HebrewDay.monthText(date, lang: lang),
            yearText: HebrewDay.yearText(date, lang: lang),
            zmanimToday: Self.zmanimRows(times, lang: lang)
        )
    }
}
