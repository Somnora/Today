import Foundation
import SwiftUI


@MainActor
class DataStore: ObservableObject {
    @Published var allEvents: [HistoricalEvent] = []
    @Published var isLoading = false
    @Published var loadIssue: EventLoadIssue?

    private var eventsByDate: [String: [HistoricalEvent]] = [:]

    /// Every distinct month/day with at least one event, sorted by calendar
    /// order. Built once per load so views don't regroup the full corpus.
    private(set) var representedDates: [MonthDay] = []

    func loadEvents() async {
        guard allEvents.isEmpty || loadIssue != nil else { return }

        isLoading = true
        loadIssue = nil

        let result = await DataLoader.loadEvents()
        allEvents = result.events
        loadIssue = result.issue
        buildDateIndex()

        isLoading = false
    }

    var availableCategories: [EventCategory] {
        EventCategory.allCases.filter { category in
            allEvents.contains(where: { $0.category == category })
        }
    }

    var representedDateCount: Int {
        representedDates.count
    }

    func eventsFor(month: Int, day: Int, tonePreference: TonePreference = .balanced, category: EventCategory? = nil) -> [HistoricalEvent] {
        let key = dateKey(month: month, day: day)
        let dated = eventsByDate[key] ?? []
        let toned = DataLoader.filterByTone(dated, preference: tonePreference)
        let filtered = category.map { chosen in toned.filter { $0.category == chosen } } ?? toned
        return filtered.sorted {
            let leftYear = $0.year ?? 0
            let rightYear = $1.year ?? 0
            if leftYear == rightYear {
                return $0.title < $1.title
            }
            return leftYear < rightYear
        }
    }

    func eventsFor(date: Date, tonePreference: TonePreference = .balanced, category: EventCategory? = nil) -> [HistoricalEvent] {
        let components = Calendar.current.dateComponents([.month, .day], from: date)
        return eventsFor(
            month: components.month ?? 1,
            day: components.day ?? 1,
            tonePreference: tonePreference,
            category: category
        )
    }

    private func buildDateIndex() {
        eventsByDate.removeAll()
        var seenDates = Set<MonthDay>()
        for event in allEvents {
            eventsByDate[dateKey(month: event.month, day: event.day), default: []].append(event)
            seenDates.insert(MonthDay(month: event.month, day: event.day))
        }
        representedDates = seenDates.sorted {
            ($0.month, $0.day) < ($1.month, $1.day)
        }
    }

    private func dateKey(month: Int, day: Int) -> String {
        String(format: "%02d-%02d", month, day)
    }
}

struct MonthDay: Hashable {
    let month: Int
    let day: Int
}
