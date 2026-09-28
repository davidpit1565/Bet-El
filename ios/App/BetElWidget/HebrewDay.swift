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

    /// A short Hebrew date string, e.g. "י״ז אדר א' תשפ״ז".
    static func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = hebrewCalendar
        formatter.locale = Locale(identifier: "he")
        formatter.dateFormat = "d MMMM y"
        return formatter.string(from: date)
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
