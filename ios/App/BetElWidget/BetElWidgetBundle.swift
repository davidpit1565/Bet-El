import WidgetKit
import SwiftUI

@main
struct BetElWidgetBundle: WidgetBundle {
    var body: some Widget {
        BetElWidget()
        BetElCandleWidget()
        BetElZmanimWidget()
        BetElTehillimWidget()
        BetElStreakWidget()
        if #available(iOS 16.0, *) {
            BetElDateLockWidget()
            BetElSunLockWidget()
        }
        if #available(iOS 16.2, *) {
            BetElLiveActivityWidget()
        }
    }
}
