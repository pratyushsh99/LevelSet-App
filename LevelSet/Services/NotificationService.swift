import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func scheduleLowTimeWarning(minutesRemaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Almost out of screen time"
        content.body = "\(minutesRemaining) minutes left today — a quick challenge can earn you more."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "com.pratyushsharma.levelset.lowTimeWarning",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
