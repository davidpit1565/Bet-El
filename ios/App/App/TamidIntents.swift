import Foundation
import AppIntents

/// Siri / Shortcuts (iOS 16+): next zman, sunset today, Hebrew date today, Omer count.
/// Everything is read from the App Group snapshot the web app already pushes for the widgets
/// (BetElSharedData: exact zmanim from the app, Omer rows, language) - no network and no app launch.
/// The deployment target stays 15.0: the whole file is gated with @available(iOS 16.0, *).
@available(iOS 16.0, *)
enum TamidSnapshot {
    private struct ZRow: Decodable { let d: String; let a: String?; let r: String?; let c: String?; let s: String?; let t: String? }
    private struct OmerRow: Decodable { let d: String; let n: Int }

    static var snapshot: BetElSharedData.Snapshot { BetElSharedData.read() }
    static var lang: String { snapshot.lang }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private static func parse(_ s: String?) -> Date? {
        guard let s = s else { return nil }
        let frac = ISO8601DateFormatter(); frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return frac.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    /// (key, time) pairs for one day, in clock order. Only what the app synced: nothing is approximated here.
    static func zmanim(on date: Date) -> [(key: String, time: Date)] {
        guard let json = snapshot.zmanimJSON, let data = json.data(using: .utf8),
              let rows = try? JSONDecoder().decode([ZRow].self, from: data),
              let row = rows.first(where: { $0.d == dayKey(date) }) else { return [] }
        let all: [(String, Date?)] = [("dawn", parse(row.a)), ("sunrise", parse(row.r)), ("chatzot", parse(row.c)), ("sunset", parse(row.s))]
        return all.compactMap { k, t in t.map { (k, $0) } }.sorted { $0.1 < $1.1 }
    }

    static func nextZman(after now: Date) -> (key: String, time: Date)? {
        for offset in 0...2 {
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: now) else { continue }
            if let hit = zmanim(on: day).first(where: { $0.time > now }) { return hit }
        }
        return nil
    }

    static func omer(on date: Date) -> Int? {
        guard let json = snapshot.omerJSON, let data = json.data(using: .utf8),
              let rows = try? JSONDecoder().decode([OmerRow].self, from: data) else { return nil }
        return rows.first(where: { $0.d == dayKey(date) })?.n
    }

    static func timeText(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        f.locale = Locale(identifier: lang)
        return f.string(from: date)
    }

    static func name(_ key: String) -> String { WidgetL10n.t(key, lang: lang) }

    /// Shown when the app has never synced (fresh install) or the synced range has run out.
    static var notSynced: String {
        switch lang {
        case "he": return "פתחו את האפליקציה פעם אחת כדי לסנכרן זמנים"
        case "fr": return "Ouvrez l’app une fois pour synchroniser les horaires"
        case "ru": return "Откройте приложение один раз, чтобы синхронизировать времена"
        case "ka": return "გახსენით აპი ერთხელ დროების სინქრონიზაციისთვის"
        default: return "Open the app once to sync the times"
        }
    }

    /// Hebrew date for "today". After sunset the Hebrew day has already turned, so use tomorrow's date once the synced sunset has passed.
    static func hebrewDateText(now: Date) -> String {
        var d = now
        if let sunset = zmanim(on: now).first(where: { $0.key == "sunset" })?.time, now > sunset,
           let next = Calendar.current.date(byAdding: .day, value: 1, to: now) { d = next }
        return HebrewDay.formatted(d, lang: lang)
    }
}

@available(iOS 16.0, *)
struct NextZmanIntent: AppIntent {
    static var title: LocalizedStringResource = "Next zman"
    static var description = IntentDescription("The next halachic time of day, with its exact time.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let text: String
        if let z = TamidSnapshot.nextZman(after: Date()) {
            text = "\(TamidSnapshot.name(z.key)): \(TamidSnapshot.timeText(z.time))"
        } else { text = TamidSnapshot.notSynced }
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

@available(iOS 16.0, *)
struct SunsetTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Sunset today"
    static var description = IntentDescription("Today's sunset time.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let text: String
        if let s = TamidSnapshot.zmanim(on: Date()).first(where: { $0.key == "sunset" }) {
            text = "\(TamidSnapshot.name("sunset")): \(TamidSnapshot.timeText(s.time))"
        } else { text = TamidSnapshot.notSynced }
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

@available(iOS 16.0, *)
struct HebrewDateTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Hebrew date today"
    static var description = IntentDescription("Today's Hebrew date.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let text = TamidSnapshot.hebrewDateText(now: Date())
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

@available(iOS 16.0, *)
struct OmerCountIntent: AppIntent {
    static var title: LocalizedStringResource = "Omer count"
    static var description = IntentDescription("Today's day of the Omer count.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let lang = TamidSnapshot.lang
        let text: String
        if let n = TamidSnapshot.omer(on: Date()) {
            // Evening counts for the next day's number (the app's rows are keyed the same way as the widget's).
            let weeks = WidgetL10n.omerWeeksLine(n, lang: lang)
            text = weeks.isEmpty ? WidgetL10n.omerDayLine(n, lang: lang) : "\(WidgetL10n.omerDayLine(n, lang: lang)) · \(weeks)"
        } else {
            text = WidgetL10n.t("omerOutside", lang: lang) + ": " + WidgetL10n.t("noCandle", lang: lang)
        }
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

@available(iOS 16.0, *)
struct TamidShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: NextZmanIntent(),
                    phrases: ["Next zman in \(.applicationName)", "What is the next zman in \(.applicationName)"],
                    shortTitle: "Next zman", systemImageName: "clock")
        AppShortcut(intent: SunsetTodayIntent(),
                    phrases: ["Sunset today in \(.applicationName)", "When is sunset in \(.applicationName)"],
                    shortTitle: "Sunset today", systemImageName: "sunset")
        AppShortcut(intent: HebrewDateTodayIntent(),
                    phrases: ["Hebrew date in \(.applicationName)", "What is the Hebrew date in \(.applicationName)"],
                    shortTitle: "Hebrew date today", systemImageName: "calendar")
        AppShortcut(intent: OmerCountIntent(),
                    phrases: ["Omer count in \(.applicationName)", "What is the Omer count in \(.applicationName)"],
                    shortTitle: "Omer count", systemImageName: "number")
    }
}
