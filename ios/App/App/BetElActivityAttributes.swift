import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Shared between the main app target (which starts/updates/ends the
/// Activity via NativeLiveActivityBridge) and the BetElWidget extension
/// target (which renders it, in BetElLiveActivityWidget.swift) - both
/// targets must compile the exact same type for `Activity<BetElActivityAttributes>`
/// to refer to the same Live Activity, the same way SharedData.swift's
/// `BetElSharedData` is already shared between them for the Home Screen
/// widget's App Group data.
///
/// `ActivityAttributes` (and everywhere it's used) is iOS 16.2+ API - this
/// file guards itself with `canImport(ActivityKit)` so it still compiles
/// on anything building against an older SDK, and every actual *use* of
/// `Activity<BetElActivityAttributes>` elsewhere is further guarded with
/// `if #available(iOS 16.2, *)` since the app's own deployment target
/// stays at 15.0.
@available(iOS 16.2, *)
struct BetElActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// The zman's own name, already in the app's current UI language
        /// (e.g. "שקיעה" / "Sunset") - computed app-side the same way
        /// everything else zman-related already is, not translated here.
        var zmanLabel: String
        var endDate: Date
    }

    /// Static for the Activity's lifetime (its own start time), shown in
    /// the Dynamic Island/Lock Screen banner alongside the live-updating
    /// countdown from `ContentState.endDate`.
    var title: String
}
#endif
