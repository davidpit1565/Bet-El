import UIKit

/// Shared helper so the native Liquid Glass UIKit components (modal, toast,
/// feedback form, tools FAB, top bar) respect the user's iOS text-size
/// accessibility setting, the same way the web app's own HTML already
/// respects it via the browser's font settings plus its own `S.fontScale`
/// control. None of these views previously used `UIFontMetrics` at all -
/// every label was a fixed `.systemFont(ofSize:)`, so changing iOS's
/// "Larger Text" setting (Settings → Accessibility → Display & Text Size)
/// had zero effect on any of them.
///
/// `maximumSize` caps how far compact chrome (a pill, a stepper's "100%"
/// label, a tab bar title) is allowed to grow before it would start
/// clipping or breaking these small fixed-size layouts - primary content
/// labels (a modal's title/body, the feedback form) that already wrap/have
/// room to grow are given a much higher or no cap at each call site.
extension UIFont {
    static func scaled(_ baseSize: CGFloat, weight: UIFont.Weight = .regular, maximumSize: CGFloat? = nil) -> UIFont {
        let base = UIFont.systemFont(ofSize: baseSize, weight: weight)
        let metrics = UIFontMetrics(forTextStyle: .body)
        if let maximumSize {
            return metrics.scaledFont(for: base, maximumPointSize: maximumSize)
        }
        return metrics.scaledFont(for: base)
    }
}

extension UILabel {
    /// Sets a Dynamic-Type-scaled font and turns on automatic rescaling
    /// when the system text size changes while this label is already on
    /// screen (Settings changes, or the Text Size control in Control
    /// Center) - the one-line replacement for every
    /// `label.font = .systemFont(ofSize:...)` this session's native views
    /// used.
    func setScaledFont(_ baseSize: CGFloat, weight: UIFont.Weight = .regular, maximumSize: CGFloat? = nil) {
        font = .scaled(baseSize, weight: weight, maximumSize: maximumSize)
        adjustsFontForContentSizeCategory = true
    }
}

extension UIColor {
    /// The app's gold, tuned per appearance for contrast on Liquid Glass:
    /// the old fixed #D4AF5F washed out on light glass, so light mode uses
    /// a deep antique gold and dark mode a brighter one. Resolves against
    /// each view's own trait collection, so views follow the app theme via
    /// their overrideUserInterfaceStyle.
    static let betelGold = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.902, green: 0.784, blue: 0.455, alpha: 1)
            : UIColor(red: 0.478, green: 0.353, blue: 0.078, alpha: 1)
    }
}

/// VoiceOver strings for native controls, in the APP language (he/en/fr/ru/ka), not the device locale.
/// JS pushes the language via `A11y.lang` (NativeTabBar.configure); unknown values fall back to English.
enum A11y {
    static var lang = "he"

    /// Fixed native chrome (bars, round buttons, cards) grows with Dynamic Type, capped so it never eats the screen.
    static var k: CGFloat { min(1.6, max(1, UIFont.preferredFont(forTextStyle: .body).pointSize / 17)) }
    static func scaled(_ v: CGFloat) -> CGFloat { ceil(v * k) }

    private static let table: [String: [String: String]] = [
        "tools": ["he": "כלי קריאה", "en": "Reading tools", "fr": "Outils de lecture", "ru": "Инструменты чтения", "ka": "კითხვის ხელსაწყოები"],
        "smaller": ["he": "הקטן טקסט", "en": "Decrease text size", "fr": "Réduire la taille du texte", "ru": "Уменьшить текст", "ka": "ტექსტის შემცირება"],
        "larger": ["he": "הגדל טקסט", "en": "Increase text size", "fr": "Augmenter la taille du texte", "ru": "Увеличить текст", "ka": "ტექსტის გადიდება"],
        "theme": ["he": "החלף מצב כהה", "en": "Toggle dark mode", "fr": "Basculer le mode sombre", "ru": "Переключить тёмную тему", "ka": "მუქი რეჟიმის გადართვა"],
        "pause": ["he": "השהה גלילה אוטומטית", "en": "Pause autoscroll", "fr": "Mettre en pause le défilement", "ru": "Приостановить прокрутку", "ka": "ავტომატური გადახვევის პაუზა"],
        "play": ["he": "התחל גלילה אוטומטית", "en": "Start autoscroll", "fr": "Lancer le défilement", "ru": "Запустить прокрутку", "ka": "ავტომატური გადახვევის დაწყება"],
        "home": ["he": "דף הבית", "en": "Home", "fr": "Accueil", "ru": "Главная", "ka": "მთავარი"],
        "back": ["he": "חזור", "en": "Back", "fr": "Retour", "ru": "Назад", "ka": "უკან"],
        "showTabs": ["he": "הצג סרגל לשוניות", "en": "Show tab bar", "fr": "Afficher la barre d'onglets", "ru": "Показать панель вкладок", "ka": "ჩანართების ჩვენება"],
        "settings": ["he": "הגדרות", "en": "Settings", "fr": "Réglages", "ru": "Настройки", "ka": "პარამეტრები"],
        "share": ["he": "שיתוף", "en": "Share", "fr": "Partager", "ru": "Поделиться", "ka": "გაზიარება"],
        "fontScale": ["he": "גודל טקסט באחוזים", "en": "Text size percent", "fr": "Taille du texte en pourcentage", "ru": "Размер текста, проценты", "ka": "ტექსტის ზომა პროცენტებში"],
    ]

    static func t(_ key: String) -> String {
        let row = table[key]
        return row?[lang] ?? row?["en"] ?? key
    }
}
