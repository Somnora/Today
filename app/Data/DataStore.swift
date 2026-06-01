import Foundation
import SwiftUI


@MainActor
class DataStore: ObservableObject {
    @Published var allEvents: [HistoricalEvent] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var loadIssue: EventLoadIssue?

    private var eventsByDate: [String: [HistoricalEvent]] = [:]

    func loadEvents() async {
        guard allEvents.isEmpty else { return }

        isLoading = true
        error = nil
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

    func eventsForToday(tonePreference: TonePreference = .balanced, category: EventCategory? = nil) -> [HistoricalEvent] {
        let today = Date()
        let components = Calendar.current.dateComponents([.month, .day], from: today)
        return eventsFor(
            month: components.month ?? 1,
            day: components.day ?? 1,
            tonePreference: tonePreference,
            category: category
        )
    }

    private func buildDateIndex() {
        eventsByDate.removeAll()
        for event in allEvents {
            eventsByDate[dateKey(month: event.month, day: event.day), default: []].append(event)
        }
    }

    private func dateKey(month: Int, day: Int) -> String {
        String(format: "%02d-%02d", month, day)
    }
}
