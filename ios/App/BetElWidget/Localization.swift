import Foundation

/// Widget chrome strings (labels that aren't already synced as plain
/// text from the app, e.g. zman labels and the streak line). Only
/// "he" and "en" are filled in for now - any other app language
/// (fr/ru/ka) falls back to Hebrew until those get their own table,
/// same fallback pattern the main app itself uses for untranslated
/// strings (see index.html's `tt()`/PRAYERS_TRANSLIT fallbacks).
enum WidgetL10n {
    private static let strings: [String: [String: String]] = [
        "dawn": ["he": "עֲלוֹת הַשַּׁחַר", "en": "Dawn"],
        "chatzot": ["he": "חֲצוֹת", "en": "Midday"],
        "zmanimToday": ["he": "זְמַנֵּי הַיּוֹם", "en": "Today's times"],
        "candleIn": ["he": "עַד הַדְלָקָה", "en": "Until candle lighting"],
        "noCandle": ["he": "אֵין הַדְלָקָה בְּקָרוֹב", "en": "No candle lighting soon"],
        "streakTitle": ["he": "רֶצֶף לִמּוּד", "en": "Study streak"],
        "best": ["he": "שִׂיא", "en": "Best"],
        "sunrise": ["he": "זְרִיחָה", "en": "Sunrise"],
        "sunset": ["he": "שְׁקִיעָה", "en": "Sunset"],
        "tehillimToday": ["he": "תְּהִלִּים הַיּוֹם", "en": "Tehillim today"],
        "chapter": ["he": "פֶּרֶק", "en": "Chapter"],
        "dayStreak": ["he": "יָמִים בְּרֶצֶף", "en": "day streak"],
        "candleLighting": ["he": "הַדְלָקַת נֵרוֹת", "en": "Candle lighting"],
        "nextZman": ["he": "הַזְּמַן הַבָּא", "en": "Next zman"],
    ]

    static func t(_ key: String, lang: String) -> String {
        let resolved = (strings[key]?[lang] != nil) ? lang : "he"
        return strings[key]?[resolved] ?? key
    }

    /// True for a language the widget lays out right-to-left for
    /// ("he", and any not-yet-translated language since its text is
    /// still Hebrew via the fallback above).
    static func isRTL(_ lang: String) -> Bool {
        lang != "en"
    }
}
