import Foundation

/// Widget chrome strings (zman names, labels...). All five app languages are filled in;
/// a missing key falls back to English (never to Hebrew, except for "he" itself).
/// Text that already arrives translated from the app (parasha/holiday names, the candle
/// label) isn't in this table.
enum WidgetL10n {
    private static let strings: [String: [String: String]] = [
        "dawn": ["he": "עֲלוֹת הַשַּׁחַר", "en": "Dawn", "fr": "Aube", "ru": "Рассвет", "ka": "განთიადი"],
        "chatzot": ["he": "חֲצוֹת", "en": "Midday", "fr": "Midi", "ru": "Полдень", "ka": "შუადღე"],
        "zmanimToday": ["he": "זְמַנֵּי הַיּוֹם", "en": "Today's times", "fr": "Horaires du jour", "ru": "Времена на сегодня", "ka": "დღევანდელი დროები"],
        "candleIn": ["he": "עַד הַדְלָקָה", "en": "Until candle lighting", "fr": "Avant l’allumage", "ru": "До зажигания", "ka": "სანთლების ანთებამდე"],
        "noCandle": ["he": "אֵין הַדְלָקָה בְּקָרוֹב", "en": "No candle lighting soon", "fr": "Pas d’allumage prochain", "ru": "Ближайшего зажигания нет", "ka": "უახლოეს დროს ანთება არ არის"],
        "streakTitle": ["he": "רֶצֶף לִמּוּד", "en": "Study streak", "fr": "Série d’étude", "ru": "Серия учёбы", "ka": "სწავლის სერია"],
        "best": ["he": "שִׂיא", "en": "Best", "fr": "Record", "ru": "Рекорд", "ka": "რეკორდი"],
        "sunrise": ["he": "זְרִיחָה", "en": "Sunrise", "fr": "Lever du soleil", "ru": "Восход", "ka": "მზის ამოსვლა"],
        "sunset": ["he": "שְׁקִיעָה", "en": "Sunset", "fr": "Coucher du soleil", "ru": "Закат", "ka": "მზის ჩასვლა"],
        "tehillimToday": ["he": "פִּרְקֵי תְּהִלִּים לְהַיּוֹם", "en": "Today's Tehillim chapters", "fr": "Chapitres de Tehilim du jour", "ru": "Главы Теилим на сегодня", "ka": "დღევანდელი თეილიმის თავები"],
        "chapter": ["he": "פֶּרֶק", "en": "Chapter", "fr": "Chapitre", "ru": "Глава", "ka": "თავი"],
        "dayStreak": ["he": "יָמִים בְּרֶצֶף", "en": "day streak", "fr": "jours d’affilée", "ru": "дней подряд", "ka": "დღე ზედიზედ"],
        "candleLighting": ["he": "הַדְלָקַת נֵרוֹת", "en": "Candle lighting", "fr": "Allumage des bougies", "ru": "Зажигание свечей", "ka": "სანთლების ანთება"],
        "nextZman": ["he": "הַזְּמַן הַבָּא", "en": "Next zman", "fr": "Prochain horaire", "ru": "Следующее время", "ka": "შემდეგი დრო"],
        "omer": ["he": "עֹמֶר", "en": "Omer", "fr": "Omer", "ru": "Омер", "ka": "ომერი"],
        "omerOutside": ["he": "סְפִירַת הָעֹמֶר", "en": "Sefirat HaOmer", "fr": "Séfirat HaOmer", "ru": "Счёт Омера", "ka": "ომერის დათვლა"],
        "omerSoon": ["he": "בֵּין פֶּסַח לְשָׁבוּעוֹת", "en": "Between Pesach and Shavuot", "fr": "Entre Pessah et Chavouot", "ru": "Между Песахом и Шавуотом", "ka": "ფესახსა და შავუოთს შორის"],
    ]

    static func t(_ key: String, lang: String) -> String {
        if let v = strings[key]?[lang] { return v }
        return strings[key]?["en"] ?? key
    }

    /// Only Hebrew lays out right-to-left (fr/ru/ka read left-to-right like English).
    static func isRTL(_ lang: String) -> Bool {
        lang == "he"
    }

    /// "היום 23 בעומר" / "Day 23 of the Omer"
    static func omerDayLine(_ n: Int, lang: String) -> String {
        switch lang {
        case "he": return "הַיּוֹם \(n) בָּעֹמֶר"
        case "fr": return "Jour \(n) de l’Omer"
        case "ru": return "День \(n) Омера"
        case "ka": return "ომერის \(n)-ე დღე"
        default: return "Day \(n) of the Omer"
        }
    }

    /// "3 שבועות ו־2 ימים" / "3 weeks and 2 days" (just the weeks when it's a whole number of weeks)
    static func omerWeeksLine(_ n: Int, lang: String) -> String {
        let w = n / 7, d = n % 7
        if w == 0 { return "" }
        switch lang {
        case "he":
            let ws = w == 1 ? "שָׁבוּעַ" : "\(w) שָׁבוּעוֹת"
            return d == 0 ? ws : "\(ws) וְ־\(d) \(d == 1 ? "יוֹם" : "יָמִים")"
        case "fr":
            let ws = "\(w) semaine\(w > 1 ? "s" : "")"
            return d == 0 ? ws : "\(ws) et \(d) jour\(d > 1 ? "s" : "")"
        case "ru":
            return d == 0 ? "\(w) нед." : "\(w) нед. \(d) дн."
        case "ka":
            return d == 0 ? "\(w) კვირა" : "\(w) კვირა და \(d) დღე"
        default:
            let ws = "\(w) week\(w > 1 ? "s" : "")"
            return d == 0 ? ws : "\(ws) and \(d) day\(d > 1 ? "s" : "")"
        }
    }
}
