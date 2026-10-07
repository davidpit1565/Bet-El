import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit

/// Renders the Live Activity `NativeLiveActivityBridge` (main app target)
/// starts/updates/ends - the Lock Screen banner plus all three Dynamic
/// Island presentations (compact/minimal/expanded). `Text(timerInterval:)`
/// is used everywhere a countdown shows, rather than a plain `Text(date,
/// style: .timer)` with a manually-recomputed string - once given a date
/// range it ticks on its own, live, driven by the system, with no app or
/// extension process needing to stay alive to update it.
@available(iOS 16.2, *)
struct BetElLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BetElActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(BetElTheme.palette(for: "dark").bgTop)
                .activitySystemActionForegroundColor(BetElTheme.palette(for: "dark").gold)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "sun.horizon.fill")
                        .foregroundColor(BetElTheme.palette(for: "dark").gold)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .monospacedDigit()
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(BetElTheme.palette(for: "dark").goldBright)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.zmanLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(BetElTheme.palette(for: "dark").ink)
                }
            } compactLeading: {
                Image(systemName: "sun.horizon.fill")
                    .foregroundColor(BetElTheme.palette(for: "dark").gold)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "sun.horizon.fill")
                    .foregroundColor(BetElTheme.palette(for: "dark").gold)
            }
        }
    }
}

@available(iOS 16.2, *)
private struct LockScreenView: View {
    let context: ActivityViewContext<BetElActivityAttributes>
    var body: some View {
        let palette = BetElTheme.palette(for: "dark")
        HStack(spacing: 12) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 26))
                .foregroundColor(palette.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.title)
                    .font(.system(size: 12))
                    .foregroundColor(palette.inkSoft)
                Text(context.state.zmanLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(palette.ink)
            }
            Spacer()
            Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                .monospacedDigit()
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(palette.goldBright)
        }
        .padding(16)
    }
}
#endif
