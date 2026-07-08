import Foundation
import UserNotifications

/// Routes taps on Morning Edition notifications to the event's detail page.
/// The tapped event ID is published here; the Today feed consumes it once the
/// catalog has loaded.
@MainActor
final class NotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    @Published var pendingEventID: String?

    /// Call before the app finishes launching so cold-start taps are caught.
    func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let eventID = response.notification.request.content.userInfo["eventID"] as? String else { return }
        await MainActor.run {
            pendingEventID = eventID
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
