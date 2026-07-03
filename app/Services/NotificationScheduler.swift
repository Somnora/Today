import Foundation
import UserNotifications

/// Schedules the local "Morning Edition" notification for the next several
/// days, using the same per-day pick as the widget. Re-run whenever the app
/// becomes active so the scheduled window keeps sliding forward. Everything
/// stays on-device; there is no push infrastructure.
enum NotificationScheduler {
    static let notificationIDPrefix = "today-morning-"
    private static let scheduledDayCount = 7
    private static let deliveryHour = 8

    /// Returns true when notifications are (or become) authorized.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }

    /// Replaces all pending Morning Edition notifications. When `enabled` is
    /// false (or authorization is missing) it only clears them.
    static func refresh(enabled: Bool, events: [HistoricalEvent]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ownedIDs = pending.map(\.identifier).filter { $0.hasPrefix(notificationIDPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ownedIDs)

        guard enabled, !events.isEmpty else { return }

        let settings = await center.notificationSettings()
        let authorizedStatuses: [UNAuthorizationStatus] = [.authorized, .provisional, .ephemeral]
        guard authorizedStatuses.contains(settings.authorizationStatus) else { return }

        let calendar = Calendar.current
        let now = Date()

        for offset in 0..<scheduledDayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }

            var fireComponents = calendar.dateComponents([.year, .month, .day], from: day)
            fireComponents.hour = deliveryHour
            guard let fireDate = calendar.date(from: fireComponents), fireDate > now else { continue }

            guard let month = fireComponents.month,
                  let dayOfMonth = fireComponents.day,
                  let event = DataLoader.displayEvent(month: month, day: dayOfMonth, from: events) else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = "Morning Edition · \(event.monthDayString)"
            content.body = "\(event.yearLabel) · \(event.title)"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(notificationIDPrefix)\(fireComponents.year ?? 0)-\(month)-\(dayOfMonth)",
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }
    }
}
