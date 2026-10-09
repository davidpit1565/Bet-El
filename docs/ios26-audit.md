# iOS 26 / Liquid Glass audit (Bet-El + halacha-yomit-ios)

Rule (user): everything that is "iOS" must be the REAL Apple iOS 26 component (Liquid Glass), with a plain
fallback for older iOS (deployment target stays 15.0). Build with the Xcode 26 SDK - apps built with it get
Liquid Glass on all system controls automatically, as long as `UIDesignRequiresCompatibility` is NOT true
(both apps now set it explicitly to `false` in Info.plist).

## Bet-El (native surface) - status
| Surface | Implementation | iOS 26 status |
|---|---|---|
| Tab bar (Home/Library/Calendar/Settings/Search) | UITabBar, no appearance overrides | Real Liquid Glass (system) |
| Top bar / header | NativeTopBarView (UIGlassEffect on 26) | Real glass |
| Tools "..." button | NativeToolsFabView (glass config) | Real glass |
| Modals (rate / celebration) | NativeModalView (UIGlassEffect) | Real glass |
| Toast | NativeToastView (UIGlassEffect) | Real glass |
| Feedback form | NativeFeedbackFormView | Real glass |
| Home edit mode (minus / resize / + / check) | NativeHomeEdit (UIButton.Configuration.glass) | Real glass |
| Long-press menu | UIAlertController action sheet | Real system sheet (glass on 26) |
| Share | navigator.share -> system share sheet | System |
| Edge-swipe back, status-bar tap, keyboard dismiss | UIScreenEdgePanGestureRecognizer / scrollsToTop / UIScrollView | System behaviour |
| Calendar | NativeCalendar.swift exists (UICalendarView) but OFF by user choice | Web design in use |
| Widgets (home, lock screen, StandBy) | WidgetKit, containerBackground + widgetAccentable | System renders glass/tinted on 26 |
| Live Activity | ActivityKit | System |

## Still HTML (CSS look-alikes of glass) - candidates to convert to real native next
Home screen tiles, Library/prayer/book lists, readers (text), Settings (kept HTML by user decision),
pull-to-refresh indicator, most cards. Text readers are fine as web content; navigation chrome is native.

## halacha-yomit-ios
UITabBar / UINavigationBar / UISearchBar (system glass on 26), SwiftUI settings + stats sheets (system sheet),
action sheet (UIAlertController), widget with containerBackground + accentable. Content is the website (HTML).

## One-time manual steps (need Xcode 26 / macOS)
1. Build with Xcode 26 SDK (older SDKs never show Liquid Glass).
2. App icon: create a layered icon in Icon Composer (Xcode 26) from the 1024 art so iOS 26 gives it the glass
   specular/depth treatment; legacy AppIcon.appiconset still works but is shown on a system plate.
