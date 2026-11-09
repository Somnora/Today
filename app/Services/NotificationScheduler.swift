import Foundation
import UserNotifications

/// One planned Morning Edition notification. Built by
/// `NotificationScheduler.plan`, which is pure so the schedule can be tested
/// without the notification center.
struct MorningEditionNotification: Equatable {
    let identifier: String
    /// Year, month, day, hour and minute in the reader's calendar.
    let fireComponents: DateComponents
    let title: String
    let body: String
    let eventID: String
}

/// Schedules the local "Morning Edition" notification, using the day's lead
/// from the editorial feed order (the same headline the feed and the widget
/// show). The schedule reaches `scheduledDayCount` days ahead so the edition
/// keeps arriving for a reader who has been away, and is rebuilt whenever
/// the app becomes active, the delivery time changes or an entry is read.
/// Everything stays on-device; there is no push infrastructure.
enum NotificationScheduler {
    static let notificationIDPrefix = "today-morning-"

    /// iOS keeps at most 64 pending local notifications per app. Sixty
    /// leaves headroom and covers two months without an open.
    static let scheduledDayCount = 60
    static let pendingNotificationLimit = 64

    /// Delivery time as minutes after midnight. 8:00 by default.
    static let defaultDeliveryMinutes = 8 * 60

    private static let refreshGate = RefreshGate()

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

    // MARK: - Plan

    /// The notifications that should be pending as of `now`: one per day at
    /// `deliveryMinutes`, starting with today when that time is still ahead.
    ///
    /// The body is the day's lead headline. One extra line may follow:
    /// - a reading streak reminder, only on the single morning the streak is
    ///   at stake. Later mornings stay silent about it, because the streak
    ///   is either already lost by then or the schedule has been rebuilt by
    ///   the read that kept it alive.
    /// - otherwise, on Fridays, a note that the weekend quiz has opened.
    static func plan(
        now: Date,
        events: [HistoricalEvent],
        feedRank: [String: Int] = [:],
        deliveryMinutes: Int = defaultDeliveryMinutes,
        streak: ReadingStreakStatus? = nil,
        calendar: Calendar = .current
    ) -> [MorningEditionNotification] {
        guard !events.isEmpty else { return [] }

        let minutes = min(max(deliveryMinutes, 0), 24 * 60 - 1)
        var planned: [MorningEditionNotification] = []

        for offset in 0..<scheduledDayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }

            var fireComponents = calendar.dateComponents([.year, .month, .day], from: day)
            fireComponents.hour = minutes / 60
            fireComponents.minute = minutes % 60
            guard let fireDate = calendar.date(from: fireComponents), fireDate > now else { continue }

            guard let year = fireComponents.year,
                  let month = fireComponents.month,
                  let dayOfMonth = fireComponents.day,
                  let event = DataLoader.displayEvent(month: month, day: dayOfMonth, from: events, feedRank: feedRank) else {
                continue
            }

            var body = "\(event.yearLabel) · \(event.title)"
            if let line = streakLine(streak: streak, dayOffset: offset) {
                body += "\n\(line)"
            } else if calendar.component(.weekday, from: fireDate) == fridayWeekday {
                body += "\n\(quizLine)"
            }

            planned.append(
                MorningEditionNotification(
                    identifier: "\(notificationIDPrefix)\(year)-\(month)-\(dayOfMonth)",
                    fireComponents: fireComponents,
                    title: "Morning Edition · \(event.monthDayString)",
                    body: body,
                    eventID: event.id
                )
            )
        }

        return planned
    }

    static let quizLine = "The weekend quiz opens today."
    private static let fridayWeekday = 6

    /// The streak reminder for the notification `dayOffset` days from today,
    /// or nil when that morning should not mention the streak.
    static func streakLine(streak: ReadingStreakStatus?, dayOffset: Int) -> String? {
        guard let streak, streak.count > 0 else { return nil }
        // With a read already logged today, the streak next needs a read
        // tomorrow. Without one, it needs a read today.
        let morningAtStake = streak.readToday ? 1 : 0
        guard dayOffset == morningAtStake else { return nil }
        if streak.count == 1 {
            return "You read yesterday. One entry today makes it two days running."
        }
        return "\(streak.count) days running. One entry today keeps your reading streak."
    }

    // MARK: - Scheduling

    /// Brings the pending Morning Edition notifications in line with the
    /// plan. When `enabled` is false (or authorization is missing) it clears
    /// them. Calls are serialized, and a call that has been overtaken
    /// by a newer one is skipped.
    static func refresh(
        enabled: Bool,
        events: [HistoricalEvent],
        feedRank: [String: Int] = [:],
        deliveryMinutes: Int = defaultDeliveryMinutes,
        streak: ReadingStreakStatus? = nil
    ) async {
        // Before the catalog has loaded there is nothing to plan from. Leave
        // the pending schedule alone rather than clearing it and rebuilding
        // it a moment later.
        if enabled, events.isEmpty { return }

        await refreshGate.run {
            await apply(
                enabled: enabled,
                events: events,
                feedRank: feedRank,
                deliveryMinutes: deliveryMinutes,
                streak: streak
            )
        }
    }

    private static func apply(
        enabled: Bool,
        events: [HistoricalEvent],
        feedRank: [String: Int],
        deliveryMinutes: Int,
        streak: ReadingStreakStatus?
    ) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let owned = pending.filter { $0.identifier.hasPrefix(notificationIDPrefix) }

        var planned: [MorningEditionNotification] = []
        if enabled, !events.isEmpty {
            let settings = await center.notificationSettings()
            let authorizedStatuses: [UNAuthorizationStatus] = [.authorized, .provisional, .ephemeral]
            if authorizedStatuses.contains(settings.authorizationStatus) {
                planned = plan(
                    now: Date(),
                    events: events,
                    feedRank: feedRank,
                    deliveryMinutes: deliveryMinutes,
                    streak: streak
                )
            }
        }

        // Add before removing. A request with a known identifier replaces
        // the pending one, so an interrupted refresh never leaves the reader
        // with fewer mornings than before.
        let existing = Dictionary(owned.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
        for item in planned {
            if let request = existing[item.identifier], matches(request, item) { continue }

            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.userInfo = ["eventID": item.eventID]

            let trigger = UNCalendarNotificationTrigger(dateMatching: item.fireComponents, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger))
        }

        let keep = Set(planned.map(\.identifier))
        let stale = owned.map(\.identifier).filter { !keep.contains($0) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }
    }

    /// True when a pending request already says what the plan wants, so the
    /// usual refresh on app activation costs no writes.
    private static func matches(_ request: UNNotificationRequest, _ item: MorningEditionNotification) -> Bool {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else { return false }
        let scheduled = trigger.dateComponents
        let wanted = item.fireComponents
        return request.content.title == item.title
            && request.content.body == item.body
            && (request.content.userInfo["eventID"] as? String) == item.eventID
            && scheduled.year == wanted.year
            && scheduled.month == wanted.month
            && scheduled.day == wanted.day
            && scheduled.hour == wanted.hour
            && scheduled.minute == wanted.minute
    }

    #if DEBUG
    /// One line per pending Morning Edition notification, in firing order.
    /// Used by the `-debugNotificationReport` launch switch.
    static func pendingReport() async -> [String] {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending
            .filter { $0.identifier.hasPrefix(notificationIDPrefix) }
            .compactMap { request -> (Date, String)? in
                guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      let fireDate = Calendar.current.date(from: trigger.dateComponents) else { return nil }
                let parts = trigger.dateComponents
                let stamp = String(
                    format: "%04d-%02d-%02d %02d:%02d",
                    parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0
                )
                let body = request.content.body.replacingOccurrences(of: "\n", with: " | ")
                return (fireDate, "\(stamp)  \(request.content.title)  \(body)")
            }
            .sorted { $0.0 < $1.0 }
            .map(\.1)
    }
    #endif
}

/// Runs schedule refreshes one at a time. A refresh that is still waiting
/// when a newer one arrives is dropped, since the newer one carries fresher
/// settings.
private actor RefreshGate {
    private var tail: Task<Void, Never>?
    private var latestTicket = 0

    func run(_ work: @escaping @Sendable () async -> Void) async {
        latestTicket += 1
        let ticket = latestTicket
        let previous = tail
        let task = Task {
            await previous?.value
            guard ticket == latestTicket else { return }
            await work()
        }
        tail = task
        await task.value
    }
}
