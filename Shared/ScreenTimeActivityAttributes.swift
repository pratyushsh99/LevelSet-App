import Foundation
import ActivityKit

struct ScreenTimeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
        var isLocked: Bool
    }

    var dailyLimitMinutes: Int
}
