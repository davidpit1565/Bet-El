import WidgetKit
import Foundation

struct ZmanRow: Identifiable {
    let key: String
    let label: String
    let time: Date
    var id: String { key }
}

/// One day's zmanim (exact ones from the app when synced, else Solar.swift's approximation).
struct ZDay {
    let dawn: Date
    let sunrise: Date
    let solarNoon: Date
    let sunset: Date
    /// nightfall - only synced once the app turns on its Hebrew-day rollover for the widgets
    let tzeit: Date?
}

extension BetElSharedData.Snapshot {
    private struct ZRowJSON: Decodable { let d: String; let a: String?; let r: String?; let c: String?; let s: String?; let t: String? }
    private struct OmerJSONRow: Decodable { let d: String; let n: Int }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    func zday(for date: Date) -> ZDay? {
        if let json = zmanimJSON, let data = json.data(using: .utf8),
           let rows = try? JSONDecoder().decode([ZRowJSON].self, from: data),
           let row = rows.first(where: { $0.d == Self.dayKey(date) }) {
            let frac = ISO8601DateFormatter(); frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            func parse(_ s: String?) -> Date? {
                guard let s = s else { return nil }
                return frac.date(from: s) ?? plain.date(from: s)
            }
            if let a = parse(row.a), let r = parse(row.r), let c = parse(row.c), let s = parse(row.s) {
                return ZDay(dawn: a, sunrise: r, solarNoon: c, sunset: s, tzeit: parse(row.t))
            }
        }
        guard let t = Solar.times(for: date, latitude: latitude, longitude: longitude) else { return nil }
        return ZDay(dawn: t.dawn, sunrise: t.sunrise, solarNoon: t.solarNoon, sunset: t.sunset, tzeit: nil)
    }

    /// The Omer count for that day (nil outside the Omer).
    func omerDay(for date: Date) -> Int? {
        guard let json = omerJSON, let data = json.data(using: .utf8),
              let rows = try? JSONDecoder().decode([OmerJSONRow].self, from: data) else { return nil }
        let key = Self.dayKey(date)
        return rows.first(where: { $0.d == key })?.n
    }
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
    /// "dark"/"light" - the widget views override this with the system appearance (SchemeResolved).
    var theme: String
    /// Mirrors the app's own S.lang ("he"/"en"/"fr"/"ru"/"ka") - see
    /// WidgetL10n for which languages the widget's own chrome text
    /// actually has a translation for.
    let lang: String
    let candleTime: Date?
    let candleLabel: String?
    let streakBest: Int
    /// Sun arc for the "day until sunset" widget: the span the sun ring tracks
    /// (sunrise -> sunset by day, sunset -> next sunrise at night) and today's two times.
    let sunStart: Date?
    let sunEnd: Date?
    let sunIsDay: Bool
    let sunriseToday: Date?
    let sunsetToday: Date?
    /// "פרשת בראשית" / the holiday's name for this day (empty if the app hasn't synced it).
    let parashaText: String
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
    /// Omer count for this Hebrew day (nil outside the Omer).
    let omerDay: Int?
    /// Smart Stack: how much this entry deserves to be on top right now.
    var relevance: TimelineEntryRelevance? = nil

    /// "א׳–ו׳" in Hebrew (letters, never digits), "1\u{2013}6" in every other language.
    var tehillimRangeText: String {
        let (a, b) = (tehillimRange.start, tehillimRange.end)
        // letters only, with air around a single dash: "מב – עב" (start on the right).
        // U+2067/U+2069 isolate it as right-to-left inside the forced-LTR widget layout.
        if lang == "he" { return "\u{2067}\(HebrewDay.gematriaPlain(a))\u{00A0}\u{2013}\u{00A0}\(HebrewDay.gematriaPlain(b))\u{2069}" }
        return "\(a)\u{2013}\(b)"
    }

    /// A stable deep link into the app for whatever this entry is
    /// currently showing - opens straight to today's Tehillim portion.
    var deepLinkURL: URL? {
        URL(string: "betel://tehillim/\(tehillimRange.start)")
    }

    /// Where a tap on each kind of widget goes (handled by the app's appUrlOpen listener).
    func link(_ kind: String) -> URL? { URL(string: "betel://\(kind)") }
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
        if let times = snapshot.zday(for: now) {
            refreshDates.append(contentsOf: [times.dawn, times.sunrise, times.solarNoon, times.sunset])
            if let tz = times.tzeit { refreshDates.append(tz) }
        }
        // Also refresh right after local midnight, for the next day's
        // Hebrew date + Tehillim portion + a fresh zmanim set.
        let cal = Calendar.current
        if let midnight = cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 1), matchingPolicy: .nextTime) {
            refreshDates.append(midnight)
        }

        // the sun ring/arc moves, so also tick every 30 minutes for the next 24 hours
        for k in 1...48 { if let d = cal.date(byAdding: .minute, value: 30 * k, to: now) { refreshDates.append(d) } }
        refreshDates = refreshDates.filter { $0 > now }.sorted()
        entries.append(makeEntry(for: now, snapshot: snapshot))
        for d in refreshDates {
            entries.append(makeEntry(for: d, snapshot: snapshot))
        }

        let reloadAfter = refreshDates.last ?? cal.date(byAdding: .hour, value: 6, to: now)!
        completion(Timeline(entries: entries, policy: .after(reloadAfter)))
    }

    private static func zmanimRows(_ times: ZDay?, lang: String) -> [ZmanRow] {
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
        let times = snapshot.zday(for: date)
        // The Hebrew day rolls over at nightfall once the app syncs tzeit (WIDGET_TZEIT_ROLLOVER in
        // index.html) - until then `tzeit` is nil and this is just the calendar date, as before.
        let hDate: Date = {
            if let tz = times?.tzeit, date >= tz { return Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date }
            return date
        }()
        let portion = HebrewDay.tehillimPortion(for: hDate)
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
                let tTimes = snapshot.zday(for: tomorrow)
                nextLabel = dawnLabel; nextTime = tTimes?.dawn
                secondLabel = tTimes != nil ? sunriseLabel : nil
                secondTime = tTimes?.sunrise
            }
        }

        // the sun span the ring follows
        var sunSpan: (start: Date?, end: Date?, isDay: Bool) = (nil, nil, true)
        if let t = times {
            let cal = Calendar.current
            if date >= t.sunrise && date < t.sunset {
                sunSpan = (t.sunrise, t.sunset, true)
            } else if date < t.sunrise {
                let y = cal.date(byAdding: .day, value: -1, to: date) ?? date
                let yT = snapshot.zday(for: y)
                sunSpan = (yT?.sunset, t.sunrise, false)
            } else {
                let tm = cal.date(byAdding: .day, value: 1, to: date) ?? date
                let tT = snapshot.zday(for: tm)
                sunSpan = (t.sunset, tT?.sunrise, false)
            }
        }

        var entry = BetElEntry(
            date: date,
            hebrewDateText: HebrewDay.formatted(hDate, lang: lang),
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
            sunStart: sunSpan.start, sunEnd: sunSpan.end, sunIsDay: sunSpan.isDay,
            sunriseToday: times?.sunrise, sunsetToday: times?.sunset,
            parashaText: snapshot.dayLabel(for: hDate),
            weekdayText: HebrewDay.weekdayText(hDate, lang: lang),
            dayText: HebrewDay.dayText(hDate, lang: lang),
            monthText: HebrewDay.monthText(hDate, lang: lang),
            yearText: HebrewDay.yearText(hDate, lang: lang),
            zmanimToday: Self.zmanimRows(times, lang: lang),
            omerDay: snapshot.omerDay(for: hDate)
        )
        // Smart Stack: rise to the top around dawn, sunrise and sunset (30 min before .. 10 min after)
        if let z = times {
            for t in [z.dawn, z.sunrise, z.sunset] where date >= t.addingTimeInterval(-1800) && date < t.addingTimeInterval(600) {
                entry.relevance = TimelineEntryRelevance(score: 80, duration: 2400)
                break
            }
        }
        return entry
    }
}
