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
