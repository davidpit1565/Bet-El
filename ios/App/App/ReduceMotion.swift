import UIKit

/// Shared helper for the spring/fade/scale animations across the native
/// Liquid Glass views (modal, toast, feedback form, tools FAB) - none of
/// them checked `UIAccessibility.isReduceMotionEnabled` before, so a
/// person with that setting on got the full transform/scale motion
/// anyway, unlike the web app's own CSS (which already has a
/// `prefers-reduced-motion` media query - see index.html). Collapsing the
/// duration to near-zero keeps the same before/after state changes
/// (so nothing just fails to appear) without the motion itself.
enum ReduceMotion {
    static var isEnabled: Bool { UIAccessibility.isReduceMotionEnabled }

    /// `fullDuration` when Reduce Motion is off, otherwise near-instant.
    static func duration(_ fullDuration: TimeInterval) -> TimeInterval {
        isEnabled ? 0.001 : fullDuration
    }
}
