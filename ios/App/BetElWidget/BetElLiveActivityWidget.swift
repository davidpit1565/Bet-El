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
                .environment(\.layoutDirection, context.attributes.rtl == true ? .rightToLeft : .leftToRight)
                .activityBackgroundTint(BetElTheme.palette(for: "dark").bgTop)
                .activitySystemActionForegroundColor(BetElTheme.palette(for: "dark").gold)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ZmanIcon(key: currentSegment(context.state, stale: context.isStale).key, size: 22)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(state: context.state, stale: context.isStale)
                        .monospacedDigit()
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(BetElTheme.palette(for: "dark").goldBright)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(currentSegment(context.state, stale: context.isStale).label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(BetElTheme.palette(for: "dark").ink)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SegmentProgress(state: context.state, stale: context.isStale)
                }
            } compactLeading: {
                ZmanIcon(key: currentSegment(context.state, stale: context.isStale).key, size: 15)
            } compactTrailing: {
                CountdownText(state: context.state, stale: context.isStale)
                    .monospacedDigit()
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: 52)
            } minimal: {
                ZmanIcon(key: currentSegment(context.state, stale: context.isStale).key, size: 14)
            }
        }
    }
}

/// SF Symbol per target zman - the icon always matches what the countdown is heading to
/// (midnight shows a moon, never a sunset).
func zmanSymbol(_ key: String?) -> String {
    switch key {
    case "dawn": return "sunrise.fill"
    case "sunrise": return "sun.max.fill"
    case "chatzot": return "sun.max.fill"
    case "sunset": return "sunset.fill"
    case "tzeit": return "moon.stars.fill"
    case "chatzotNight": return "moon.fill"
    default: return "sun.horizon.fill"
    }
}

@available(iOS 16.2, *)
private struct ZmanIcon: View {
    let key: String?
    let size: CGFloat
    var body: some View {
        Image(systemName: zmanSymbol(key))
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(BetElTheme.palette(for: "dark").goldBright, BetElTheme.palette(for: "dark").gold)
    }
}

@available(iOS 16.2, *)
private struct SegmentProgress: View {
    let state: BetElActivityAttributes.ContentState
    var stale: Bool = false
    var body: some View {
        let seg = currentSegment(state, stale: stale)
        if let end = seg.end, seg.start < end {
            ProgressView(timerInterval: seg.start...end, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                .progressViewStyle(.linear)
                .tint(BetElTheme.palette(for: "dark").gold)
        }
    }
}

@available(iOS 16.2, *)
private struct LockScreenView: View {
    let context: ActivityViewContext<BetElActivityAttributes>
    var body: some View {
        /* Picks the first layout that fits the height the system gives us: the full banner on the Lock Screen, and a
           single compact row when the space is small (CarPlay, StandBy, Watch Smart Stack mirrors, any short banner). */
        ViewThatFits(in: .vertical) {
            fullLayout
            compactLayout
        }
    }

    private var compactLayout: some View {
        let palette = BetElTheme.palette(for: "dark")
        let seg = currentSegment(context.state, stale: context.isStale)
        return HStack(spacing: 8) {
            ZmanIcon(key: seg.key, size: 18)
            Text(seg.label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(palette.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            Spacer(minLength: 4)
            CountdownText(state: context.state, stale: context.isStale)
                .monospacedDigit()
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(palette.goldBright)
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var fullLayout: some View {
        let palette = BetElTheme.palette(for: "dark")
        let seg = currentSegment(context.state, stale: context.isStale)
        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(palette.gold.opacity(0.16))
                    Circle().stroke(palette.gold.opacity(0.45), lineWidth: 1)
                    ZmanIcon(key: seg.key, size: 24)
                }
                .frame(width: 50, height: 50)
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.title)
                        .font(.system(size: 12))
                        .foregroundColor(palette.inkSoft)
                    Text(seg.label)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    if let end = seg.end {
                        Text(end, style: .time)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(palette.gold)
                    }
                }
                Spacer(minLength: 8)
                CountdownText(state: context.state, stale: context.isStale)
                    .monospacedDigit()
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(palette.goldBright)
                    .minimumScaleFactor(0.6).lineLimit(1)
            }
            SegmentProgress(state: context.state, stale: context.isStale)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

/// The countdown segment to show right now: the stored zman, or - once it has passed and the
/// app hasn't refreshed the Activity yet - the next one from the chain the content carries
/// (`upcoming`, plus the older nextLabel/nextDate pair). `Text(timerInterval:)` needs a valid
/// range (lowerBound <= upperBound; an inverted range crashes the whole widget extension), and
/// a passed end date would freeze at 0:00, so neither case ever reaches it.
@available(iOS 16.2, *)
func currentSegment(_ state: BetElActivityAttributes.ContentState, now: Date = Date(), stale: Bool = false) -> (label: String, key: String?, start: Date, end: Date?) {
    var chain: [(String, String?, Date)] = [(state.zmanLabel, state.zmanKey, state.endDate)]
    if let ups = state.upcoming, !ups.isEmpty {
        chain += ups.map { ($0.label, Optional($0.key), $0.date) }
    } else if let d = state.nextDate {
        chain.append((state.nextLabel ?? state.zmanLabel, nil, d))
    }
    /* The system re-renders the Activity exactly when its staleDate (= the first zman) passes, but at that instant
       `now` can still be a hair BEFORE that date - so the first segment was picked again and its countdown sat at
       0:00:00 until the app was opened. `context.isStale` says the first zman is over, and a 2s margin covers a render
       that lands just before the boundary: either way the next segment is shown. */
    let margin: TimeInterval = 2
    var start = min(state.startDate ?? now, now)
    for (i, (label, key, end)) in chain.enumerated() {
        if stale && i == 0 { start = end; continue }
        if end > now.addingTimeInterval(margin) { return (label, key, start, end) }
        start = end
    }
    return (state.zmanLabel, state.zmanKey, now, nil)
}

@available(iOS 16.2, *)
private struct CountdownText: View {
    let state: BetElActivityAttributes.ContentState
    var stale: Bool = false
    var body: some View {
        let seg = currentSegment(state, stale: stale)
        if let end = seg.end, seg.start < end {
            Text(timerInterval: seg.start...end, countsDown: true)
        } else {
            Image(systemName: "arrow.clockwise")
        }
    }
}
#endif
