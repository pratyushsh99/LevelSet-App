import Foundation
import ActivityKit

enum LiveActivityService {
    private static var currentActivity: Activity<ScreenTimeActivityAttributes>?

    static func start(endDate: Date, dailyLimitMinutes: Int, isLocked: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard currentActivity == nil else {
            update(endDate: endDate, isLocked: isLocked)
            return
        }

        let attributes = ScreenTimeActivityAttributes(dailyLimitMinutes: dailyLimitMinutes)
        let state = ScreenTimeActivityAttributes.ContentState(endDate: endDate, isLocked: isLocked)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
        }
    }

    static func update(endDate: Date, isLocked: Bool) {
        guard let activity = currentActivity else { return }
        let state = ScreenTimeActivityAttributes.ContentState(endDate: endDate, isLocked: isLocked)
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    static func end() {
        guard let activity = currentActivity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        currentActivity = nil
    }
}
