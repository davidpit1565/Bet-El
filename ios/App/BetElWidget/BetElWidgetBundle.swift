import WidgetKit
import SwiftUI

@main
struct BetElWidgetBundle: WidgetBundle {
    var body: some Widget {
        BetElWidget()
        BetElCandleWidget()
    }
}
