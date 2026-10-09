import Foundation

/// Small Hebrew-calendar helpers for the widget, using Foundation's
/// built-in Hebrew calendar (no need to port hebcal's own JS logic for
/// this) - just enough to show today's Hebrew date and compute today's
/// Tehillim portion the same way the app itself does.
enum HebrewDay {
    static var hebrewCalendar: Calendar {
        var cal = Calendar(identifier: .hebrew)
        cal.locale = Locale(identifier: "he")
        return cal
    }

    // MARK: - Date text
    //
    // In Hebrew the date reads with Hebrew letters throughout - day, month
    // and year ("כ״ו תשרי תשפ״ז"), never "26 תשרי 5787"; in English it is
    // plain numerals with the month spelled in English ("26 Tishrei 5787").
    // Any language the widget has no table for falls back to Hebrew, same as
    // the rest of the widget's text (see WidgetL10n).

    /// Hebrew numerals with geresh/gershayim ("כ״ו", "ט״ו", "תשפ״ז", "ל׳").
    static func gematria(_ number: Int) -> String {
        let table: [(Int, String)] = [
            (400, "ת"), (300, "ש"), (200, "ר"), (100, "ק"), (90, "צ"), (80, "פ"),
            (70, "ע"), (60, "ס"), (50, "נ"), (40, "מ"), (30, "ל"), (20, "כ"),
            (10, "י"), (9, "ט"), (8, "ח"), (7, "ז"), (6, "ו"), (5, "ה"),
            (4, "ד"), (3, "ג"), (2, "ב"), (1, "א"),
        ]
        var remaining = number
        var letters: [String] = []
        // 15 and 16 are written ט״ו / ט״ז (never י״ה / י״ו, which spell a divine name)
        if remaining % 100 == 15 { letters.append(contentsOf: lettersFor(remaining - 15, table)); letters.append("ט"); letters.append("ו"); return punctuate(letters) }
        if remaining % 100 == 16 { letters.append(contentsOf: lettersFor(remaining - 16, table)); letters.append("ט"); letters.append("ז"); return punctuate(letters) }
        letters = lettersFor(remaining, table)
        remaining = 0
        return punctuate(letters)
    }

    /// Hebrew numeral letters only - no geresh/gershayim marks ("מב", "ע", "קמ").
    static func gematriaPlain(_ number: Int) -> String {
        gematria(number).replacingOccurrences(of: "\u{05F3}", with: "").replacingOccurrences(of: "\u{05F4}", with: "")
    }

    private static func lettersFor(_ value: Int, _ table: [(Int, String)]) -> [String] {
        var remaining = value
        var out: [String] = []
        for (n, letter) in table {
            while remaining >= n { out.append(letter); remaining -= n }
        }
        return out
    }

    private static func punctuate(_ letters: [String]) -> String {
        guard !letters.isEmpty else { return "" }
        if letters.count == 1 { return letters[0] + "\u{05F3}" }
        return letters.dropLast().joined() + "\u{05F4}" + letters.last!
    }

    private static func isHebrew(_ lang: String) -> Bool { lang == "he" }

    /// Month names the app itself uses (index.html MONTHS_*), keyed by a canonical English name.
    private static let monthTables: [String: [String: String]] = [
        "fr": ["Nisan": "Nissan", "Iyar": "Iyar", "Sivan": "Sivan", "Tammuz": "Tamouz", "Av": "Av", "Elul": "Éloul", "Tishrei": "Tichri",
               "Cheshvan": "Hèchvan", "Kislev": "Kislev", "Tevet": "Tévét", "Shvat": "Chevat", "Adar": "Adar", "Adar I": "Adar I", "Adar II": "Adar II"],
        "ru": ["Nisan": "Нисан", "Iyar": "Ияр", "Sivan": "Сиван", "Tammuz": "Таммуз", "Av": "Ав", "Elul": "Элул", "Tishrei": "Тишрей",
               "Cheshvan": "Хешван", "Kislev": "Кислев", "Tevet": "Тевет", "Shvat": "Шват", "Adar": "Адар", "Adar I": "Адар I", "Adar II": "Адар II"],
        "ka": ["Nisan": "ნისანი", "Iyar": "იარი", "Sivan": "სივანი", "Tammuz": "თამუზი", "Av": "აბი", "Elul": "ელული", "Tishrei": "თიშრეი",
               "Cheshvan": "ხეშვანი", "Kislev": "ქისლევი", "Tevet": "თევეთი", "Shvat": "შვატი", "Adar": "ადარი", "Adar I": "ადარი I", "Adar II": "ადარ II"],
    ]

    private static let weekdayTables: [String: [String]] = [
        "en": ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Shabbat"],
        "fr": ["Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Chabbat"],
        "ru": ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Шаббат"],
        "ka": ["კვირა", "ორშაბათი", "სამშაბათი", "ოთხშაბათი", "ხუთშაბათი", "პარასკევი", "შაბათი"],
    ]

    private static func monthName(_ date: Date, lang: String) -> String {
        let locale = Locale(identifier: isHebrew(lang) ? "he" : "en")
        var cal = Calendar(identifier: .hebrew)
        cal.locale = locale
        let f = DateFormatter()
        f.calendar = cal
        f.locale = locale
        f.dateFormat = "MMMM"
        let raw = f.string(from: date)
        // Foundation's spellings differ a little from the ones the app itself uses
        if isHebrew(lang) { return ["חשוון": "חשון", "סיוון": "סיון"][raw] ?? raw }
        let canonical = ["Tishri": "Tishrei", "Heshvan": "Cheshvan", "Shevat": "Shvat", "Tamuz": "Tammuz"][raw] ?? raw
        return monthTables[lang]?[canonical] ?? canonical
    }

    /// Day of the Hebrew month: "כ״ו" / "26".
    static func dayText(_ date: Date, lang: String) -> String {
        let day = hebrewCalendar.component(.day, from: date)
        return isHebrew(lang) ? gematria(day) : String(day)
    }

    /// Hebrew month name: "תשרי" / "Tishrei".
    static func monthText(_ date: Date, lang: String) -> String {
        monthName(date, lang: lang)
    }

    /// Hebrew year: "תשפ״ז" / "5787".
    static func yearText(_ date: Date, lang: String) -> String {
        let year = hebrewCalendar.component(.year, from: date)
        return isHebrew(lang) ? gematria(year % 1000) : String(year)
    }

    /// Weekday: "יום רביעי" / "Wednesday".
    static func weekdayText(_ date: Date, lang: String) -> String {
        if let table = weekdayTables[lang] {
            let idx = Calendar(identifier: .gregorian).component(.weekday, from: date) - 1   // 1 = Sunday
            return table[max(0, min(6, idx))]
        }
        let locale = Locale(identifier: "he")
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "EEEE"
        let name = f.string(from: date)
        return !name.hasPrefix("יום") ? "יום " + name : name
    }

    /// The whole date on one line: "כ״ו תשרי תשפ״ז" / "26 Tishrei 5787".
    static func formatted(_ date: Date, lang: String = "he") -> String {
        "\(dayText(date, lang: lang)) \(monthText(date, lang: lang)) \(yearText(date, lang: lang))"
    }

    /// Same division the app's own monthlyPortion(hd) uses: 5 chapters
    /// per Hebrew calendar day-of-month (1-30), day 30 in a 29-day month
    /// repeating day 29's own portion (there's no 30th slot printed in
    /// the classic 30-day table this mirrors). Returns a 1-indexed
    /// (start, end) chapter range within Tehillim's 150 chapters.
    static func tehillimPortion(for date: Date) -> (start: Int, end: Int) {
        let cal = hebrewCalendar
        let day = cal.component(.day, from: date)
        let daysInMonth = cal.range(of: .day, in: .month, for: date)?.count ?? 30
        if daysInMonth == 29 && day == 29 {
            return (141, 150)
        }
        let start = 5 * (day - 1) + 1
        let end = min(150, start + 4)
        return (start, end)
    }
}
