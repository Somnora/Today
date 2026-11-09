import Foundation

class DataLoader {
    /// Loads the first bundled collection found among `resourceCandidates`.
    /// The app bundles the full corpus as "events"; the widget extension
    /// bundles the compact per-day slice as "widget-events".
    static func loadEvents(resourceCandidates: [String] = ["events"]) async -> EventLoadResult {
        let url = resourceCandidates
            .lazy
            .compactMap { Bundle.main.url(forResource: $0, withExtension: "json") }
            .first

        guard let url else {
            return EventLoadResult(events: fallbackEvents(), issue: .missingCollection)
        }

        do {
            let data = try Data(contentsOf: url)
            let eventsData = try decodeEventsData(from: data)

            let directEvents = eventsData.events
            let bundledEvents = (eventsData.robBundles ?? []).flatMap(bundleEvents(from:))
            let merged = deduplicatedEvents(from: directEvents + bundledEvents).filter(\.isPublishable)

            if merged.isEmpty {
                return EventLoadResult(events: fallbackEvents(), issue: .emptyCollection)
            }

            return EventLoadResult(events: merged, issue: nil)
        } catch {
            return EventLoadResult(events: fallbackEvents(), issue: .invalidCollection)
        }
    }

    static func filterByTone(_ events: [HistoricalEvent], preference: TonePreference) -> [HistoricalEvent] {
        switch preference {
        case .uplifting:
            let uplifting = events.filter { $0.tone == .uplifting }
            if !uplifting.isEmpty {
                return uplifting
            }
            return filterByTone(events, preference: .balanced)
        case .balanced:
            let balanced = events.filter { $0.tone != .somber || $0.category == .history || $0.category == .politics }
            if !balanced.isEmpty {
                return balanced
            }
            return events
        case .unflinching:
            return events
        }
    }

    /// The single event surfaced for a given day on ambient surfaces (the
    /// morning notification): balanced tone policy, then the editorial feed
    /// order, so it matches the lead card and the widget. Without a rank it
    /// falls back to the earliest year with title as tiebreaker.
    static func displayEvent(
        month: Int,
        day: Int,
        from events: [HistoricalEvent],
        feedRank: [String: Int] = [:]
    ) -> HistoricalEvent? {
        let dated = events.filter { $0.matches(month: month, day: day) }
        let preferred = filterByTone(dated, preference: .balanced)
        return feedOrdered(preferred, rank: feedRank).first
    }

    /// Editorial order for a day's events: ranked records first, in rank
    /// order, then any unranked records by year and title.
    static func feedOrdered(_ events: [HistoricalEvent], rank: [String: Int]) -> [HistoricalEvent] {
        events.sorted { left, right in
            switch (rank[left.id], rank[right.id]) {
            case let (leftRank?, rightRank?) where leftRank != rightRank:
                return leftRank < rightRank
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                return displayOrder(left, right)
            }
        }
    }

    /// Loads the bundled editorial feed order as event ID -> position within
    /// its day. Returns an empty map when the file is missing or malformed;
    /// callers then fall back to chronological order.
    static func loadFeedRank(resource: String = "feed-order") async -> [String: Int] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return feedRank(from: data)
    }

    static func feedRank(from data: Data) -> [String: Int] {
        guard let order = try? JSONDecoder().decode(FeedOrder.self, from: data) else { return [:] }
        var rank: [String: Int] = [:]
        for ids in order.days.values {
            for (position, id) in ids.enumerated() where rank[id] == nil {
                rank[id] = position
            }
        }
        return rank
    }

    static func displayOrder(_ left: HistoricalEvent, _ right: HistoricalEvent) -> Bool {
        let leftYear = left.year ?? 0
        let rightYear = right.year ?? 0
        if leftYear == rightYear {
            return left.title < right.title
        }
        return leftYear < rightYear
    }

    /// The slice is already editorially ranked. Preserve its order and never
    /// substitute an unrelated date when a day is missing. Empty days still
    /// receive an entry so yesterday's history is cleared at midnight.
    static func widgetDays(from events: [HistoricalEvent], startingAt now: Date, timeZone: TimeZone = .current) -> [WidgetDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: now)
        return (0..<3).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let components = calendar.dateComponents([.month, .day], from: date)
            let highlights = events.filter {
                $0.isPublishable && $0.month == components.month && $0.day == components.day
            }
            return WidgetDay(date: offset == 0 ? now : date, events: Array(highlights.prefix(3)))
        }
    }

    private static func bundleEvents(from bundle: RobBundleEnvelope) -> [HistoricalEvent] {
        let combined = bundle.publishableUplifting + bundle.publishableBalanced
        return combined.compactMap(HistoricalEvent.init(bundleRecord:))
    }

    private static func deduplicatedEvents(from events: [HistoricalEvent]) -> [HistoricalEvent] {
        var seen = Set<String>()
        return events.filter { event in
            seen.insert(event.id).inserted
        }
    }

    private static func decodeEventsData(from data: Data) throws -> EventsData {
        let decoder = JSONDecoder()

        if let topLevelEvents = try? decoder.decode([FailableDecodable<HistoricalEvent>].self, from: data) {
            return EventsData(events: topLevelEvents.compactMap(\.value), robBundles: nil)
        }

        return try decoder.decode(EventsData.self, from: data)
    }

    private static func fallbackEvents(date: Date = Date()) -> [HistoricalEvent] {
        let components = Calendar.current.dateComponents([.month, .day], from: date)

        return [
            HistoricalEvent(
                id: "offline-note",
                month: components.month ?? 1,
                day: components.day ?? 1,
                year: nil,
                title: "Today is opening a smaller note",
                summary: "The full collection is temporarily unavailable, so Today is showing a simple offline card.",
                contextLine: "Even a quiet fallback should keep the daily habit intact.",
                detail: "Today stores its historical collection inside the app. If that collection cannot be opened, this offline card keeps the app usable until an updated build restores the complete library.",
                category: .history,
                tone: .balanced,
                source: "Today"
            )
        ]
    }
}

struct FeedOrder: Decodable {
    let version: Int
    let days: [String: [String]]
}

struct WidgetDay {
    let date: Date
    let events: [HistoricalEvent]
}

struct EventLoadResult {
    let events: [HistoricalEvent]
    let issue: EventLoadIssue?
}

enum EventLoadIssue: LocalizedError, Equatable {
    case missingCollection
    case invalidCollection
    case emptyCollection

    var errorDescription: String? {
        switch self {
        case .missingCollection, .invalidCollection, .emptyCollection:
            return "Today could not open its built-in collection. A short offline note is available while the collection is restored."
        }
    }

    var shortStatus: String {
        switch self {
        case .missingCollection:
            return "Offline note active"
        case .invalidCollection:
            return "Collection check needed"
        case .emptyCollection:
            return "Offline note active"
        }
    }
}

extension EventsData {
    init(events: [HistoricalEvent], robBundles: [RobBundleEnvelope]?) {
        self.events = events
        self.robBundles = robBundles
    }
}

enum TonePreference: String, CaseIterable {
    case uplifting = "Uplifting"
    case balanced = "Balanced"
    case unflinching = "Unflinching"

    var editorialLabel: String {
        switch self {
        case .uplifting: return "lighter, steadier, more hopeful"
        case .balanced: return "the full, tasteful spread of the day"
        case .unflinching: return "the whole record, harder truths included"
        }
    }
}
