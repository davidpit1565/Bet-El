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
