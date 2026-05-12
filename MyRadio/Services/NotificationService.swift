import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    private static var didRequestAuthorization = false

    static func requestAuthorizationIfNeeded() {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func fireSleepTimerExpired() {
        let content = UNMutableNotificationContent()
        content.title = "Sleep timer finished"
        content.body = "Playback has been stopped."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "sleep-timer-expired",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
