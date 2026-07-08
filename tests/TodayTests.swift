import SwiftUI
import XCTest
@testable import Today

// MARK: - Fixtures

private func makeEvent(
    id: String = UUID().uuidString,
    month: Int = 7,
    day: Int = 10,
    year: Int? = 1900,
    title: String = "Fixture event",
    tone: EventTone = .balanced,
    category: EventCategory = .science,
    imageURL: String? = nil
) -> HistoricalEvent {
    HistoricalEvent(
        id: id,
        month: month,
        day: day,
        year: year,
        title: title,
        summary: "Fixture summary for \(title).",
        contextLine: "Fixture context line.",
        detail: "Fixture detail for \(title).",
        category: category,
        tone: tone,
        source: "https://example.com/fixture",
        imageURLString: imageURL
    )
}

/// A corpus large and clean enough for QuizEngine: distinct years, no digit
/// runs in titles, spread across the calendar including the quiz anchor day.
private func makeQuizCorpus() -> [HistoricalEvent] {
    let names = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta",
                 "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi", "Omicron", "Pi"]
    return (0..<200).map { index in
        makeEvent(
            id: String(format: "fixture-%03d", index),
            month: (index % 12) + 1,
            day: (index % 28) + 1,
            year: 1500 + index,
            title: "The \(names[index % names.count]) expedition set sail, attempt \(names[(index / 16) % names.count])",
            tone: index % 7 == 0 ? .uplifting : .balanced,
            imageURL: "https://example.com/image-\(index).jpg"
        )
    }
}

// MARK: - Tone filtering

final class ToneFilteringTests: XCTestCase {
    func testUpliftingKeepsOnlyUpliftingWhenPresent() {
        let events = [
            makeEvent(id: "a", tone: .uplifting),
            makeEvent(id: "b", tone: .balanced),
            makeEvent(id: "c", tone: .somber)
        ]
        let filtered = DataLoader.filterByTone(events, preference: .uplifting)
        XCTAssertEqual(filtered.map(\.id), ["a"])
    }

    func testUpliftingFallsBackToBalancedPolicy() {
        let events = [
            makeEvent(id: "b", tone: .balanced),
            makeEvent(id: "c", tone: .somber, category: .science)
        ]
        let filtered = DataLoader.filterByTone(events, preference: .uplifting)
        XCTAssertEqual(filtered.map(\.id), ["b"])
    }

    func testBalancedKeepsSomberHistoryAndPoliticsOnly() {
        let events = [
            makeEvent(id: "a", tone: .balanced),
            makeEvent(id: "b", tone: .somber, category: .history),
            makeEvent(id: "c", tone: .somber, category: .politics),
            makeEvent(id: "d", tone: .somber, category: .science)
        ]
        let filtered = DataLoader.filterByTone(events, preference: .balanced)
        XCTAssertEqual(Set(filtered.map(\.id)), ["a", "b", "c"])
    }

    func testUnflinchingReturnsEverything() {
        let events = [
            makeEvent(id: "a", tone: .uplifting),
            makeEvent(id: "b", tone: .somber, category: .science),
            makeEvent(id: "c", tone: .somber, category: .history)
        ]
        let filtered = DataLoader.filterByTone(events, preference: .unflinching)
        XCTAssertEqual(filtered.count, 3)
    }
}

// MARK: - Ambient-surface pick

final class DisplayEventTests: XCTestCase {
    func testPicksEarliestYearFromBalancedPool() {
        let events = [
            makeEvent(id: "later", year: 1950),
            makeEvent(id: "earlier", year: 1800),
            makeEvent(id: "somber-earliest", year: 1700, tone: .somber, category: .science),
            makeEvent(id: "other-day", month: 1, day: 1, year: 1600)
        ]
        let pick = DataLoader.displayEvent(month: 7, day: 10, from: events)
        XCTAssertEqual(pick?.id, "earlier")
    }

    func testTitleBreaksYearTies() {
        let events = [
            makeEvent(id: "z", year: 1900, title: "Zebra crossing opens"),
            makeEvent(id: "a", year: 1900, title: "Aqueduct completed")
        ]
        let pick = DataLoader.displayEvent(month: 7, day: 10, from: events)
        XCTAssertEqual(pick?.id, "a")
    }
}

// MARK: - Quiz engine

final class QuizEngineTests: XCTestCase {
    private static let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testQuizDaysAreFridayAndSunday() {
        XCTAssertTrue(QuizEngine.isQuizDay(date(2026, 7, 10)))   // Friday
        XCTAssertTrue(QuizEngine.isQuizDay(date(2026, 7, 12)))   // Sunday
        XCTAssertFalse(QuizEngine.isQuizDay(date(2026, 7, 7)))   // Tuesday
        XCTAssertFalse(QuizEngine.isQuizDay(date(2026, 7, 11)))  // Saturday
    }

    func testWeekKeyMatchesISOWeek() {
        XCTAssertEqual(QuizEngine.weekKey(for: date(2026, 7, 10)), "2026-W28")
        // ISO weeks run Monday-Sunday, so Sunday shares Friday's key.
        XCTAssertEqual(QuizEngine.weekKey(for: date(2026, 7, 12)), "2026-W28")
        // January 1st 2027 belongs to ISO week 53 of 2026.
        XCTAssertEqual(QuizEngine.weekKey(for: date(2027, 1, 1)), "2026-W53")
    }

    func testAnchorDayIsTheFridayOfTheWeek() {
        let anchor = QuizEngine.anchorDay(for: date(2026, 7, 12))
        XCTAssertEqual(anchor, MonthDay(month: 7, day: 10))
    }

    func testQuizIsDeterministicAcrossDaysAndInputOrder() {
        let corpus = makeQuizCorpus()
        let friday = QuizEngine.quiz(for: date(2026, 7, 10), events: corpus)
        let sunday = QuizEngine.quiz(for: date(2026, 7, 12), events: corpus)
        let shuffled = QuizEngine.quiz(for: date(2026, 7, 10), events: corpus.shuffled())
        XCTAssertNotNil(friday)
        XCTAssertEqual(friday, sunday)
        XCTAssertEqual(friday, shuffled)
    }

    func testQuizVariesWeekToWeek() {
        let corpus = makeQuizCorpus()
        let thisWeek = QuizEngine.quiz(for: date(2026, 7, 10), events: corpus)
        let nextWeek = QuizEngine.quiz(for: date(2026, 7, 17), events: corpus)
        XCTAssertNotEqual(thisWeek, nextWeek)
    }

    func testQuizStructureIsSound() throws {
        let quiz = try XCTUnwrap(QuizEngine.quiz(for: date(2026, 7, 10), events: makeQuizCorpus()))
        XCTAssertEqual(quiz.questions.count, QuizEngine.questionCount)
        for question in quiz.questions {
            XCTAssertFalse(question.options.isEmpty)
            XCTAssertEqual(Set(question.options).count, question.options.count, "options must be distinct")
            XCTAssertTrue(question.options.indices.contains(question.correctIndex))
            XCTAssertFalse(question.note.isEmpty)
        }
    }

    func testQuizReturnsNilForThinCorpus() {
        let thin = Array(makeQuizCorpus().prefix(20))
        XCTAssertNil(QuizEngine.quiz(for: date(2026, 7, 10), events: thin))
    }

    func testQuizGeneratesFromTheBundledCorpus() async {
        let result = await DataLoader.loadEvents()
        XCTAssertNil(result.issue)
        XCTAssertGreaterThan(result.events.count, 3_500)
        let quiz = QuizEngine.quiz(for: date(2026, 7, 10), events: result.events)
        XCTAssertNotNil(quiz)
    }
}

// MARK: - Quiz results and streaks

@MainActor
final class QuizStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "quizResultsV1")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "quizResultsV1")
        super.tearDown()
    }

    func testOnlyFirstAttemptCounts() {
        let store = QuizStore()
        store.recordResult(weekKey: "2026-W28", score: 3, total: 5)
        store.recordResult(weekKey: "2026-W28", score: 5, total: 5)
        XCTAssertEqual(store.result(for: "2026-W28"), QuizResult(score: 3, total: 5))
    }

    func testResultsSurviveReload() {
        QuizStore().recordResult(weekKey: "2026-W28", score: 4, total: 5)
        XCTAssertEqual(QuizStore().result(for: "2026-W28")?.score, 4)
    }

    func testStreakCountsConsecutiveWeeksAndToleratesUnplayedCurrentWeek() {
        let store = QuizStore()
        let calendar = QuizEngine.isoCalendar
        let now = Date()
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: now)!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: now)!

        store.recordResult(weekKey: QuizEngine.weekKey(for: lastWeek), score: 4, total: 5)
        store.recordResult(weekKey: QuizEngine.weekKey(for: twoWeeksAgo), score: 5, total: 5)
        store.recordResult(weekKey: QuizEngine.weekKey(for: fourWeeksAgo), score: 2, total: 5)

        // Current week unplayed: last two weeks count, the gap ends the run.
        XCTAssertEqual(store.streak(asOf: now), 2)

        store.recordResult(weekKey: QuizEngine.weekKey(for: now), score: 3, total: 5)
        XCTAssertEqual(store.streak(asOf: now), 3)
    }

    func testStreakIsZeroWithNoHistory() {
        XCTAssertEqual(QuizStore().streak(asOf: Date()), 0)
    }
}

// MARK: - Saved bookmarks

@MainActor
final class SavedStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "savedEventIDs")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "savedEventIDs")
        super.tearDown()
    }

    func testToggleSavesAndRemoves() {
        let store = SavedStore()
        XCTAssertFalse(store.isSaved("event-1"))
        store.toggle("event-1")
        XCTAssertTrue(store.isSaved("event-1"))
        store.toggle("event-1")
        XCTAssertFalse(store.isSaved("event-1"))
    }

    func testSavedIDsSurviveReload() {
        SavedStore().toggle("event-2")
        XCTAssertTrue(SavedStore().isSaved("event-2"))
    }

    func testBlankIDsAreRejected() {
        let store = SavedStore()
        store.toggle("   ")
        XCTAssertTrue(store.savedIDs.isEmpty)
    }
}

// MARK: - Share card rendering

@MainActor
final class ShareCardTests: XCTestCase {
    func testShareCardRendersAnImage() {
        let event = makeEvent(title: "Apollo program fixture", tone: .uplifting, category: .exploration)
        XCTAssertNotNil(ShareCardRenderer.image(for: event))
    }
}
