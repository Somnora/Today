import Foundation
import SwiftUI

struct QuizResult: Codable, Equatable {
    let score: Int
    let total: Int
}

/// Completed weekly-quiz results, keyed by ISO week ("2026-W28"), persisted
/// as JSON in AppStorage.
@MainActor
final class QuizStore: ObservableObject {
    @AppStorage("quizResultsV1") private var resultsData: String = "{}"
    @Published private(set) var results: [String: QuizResult] = [:]

    init() {
        loadResults()
    }

    func result(for weekKey: String) -> QuizResult? {
        results[weekKey]
    }

    /// Only the first completed attempt of a week is recorded; replays are
    /// just for fun.
    func recordResult(weekKey: String, score: Int, total: Int) {
        guard results[weekKey] == nil else { return }
        results[weekKey] = QuizResult(score: score, total: total)
        saveResults()
    }

    /// Consecutive quiz weeks completed, counting back from the given date.
    /// An unplayed current week doesn't break the streak — it just doesn't
    /// count yet.
    func streak(asOf date: Date) -> Int {
        let calendar = QuizEngine.isoCalendar
        var cursor = date
        if results[QuizEngine.weekKey(for: cursor)] == nil {
            guard let previous = calendar.date(byAdding: .day, value: -7, to: cursor) else { return 0 }
            cursor = previous
        }

        var count = 0
        while results[QuizEngine.weekKey(for: cursor)] != nil {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -7, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private func loadResults() {
        guard let data = resultsData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: QuizResult].self, from: data) else {
            results = [:]
            return
        }
        results = decoded
    }

    private func saveResults() {
        guard let data = try? JSONEncoder().encode(results),
              let encoded = String(data: data, encoding: .utf8) else { return }
        resultsData = encoded
    }
}
