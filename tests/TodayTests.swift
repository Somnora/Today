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

    func testFeedRankOverridesChronologyForFeedAndAmbientPick() {
        let events = [
            makeEvent(id: "old", year: 1200),
            makeEvent(id: "headline", year: 1989),
            makeEvent(id: "second", year: 1905),
            makeEvent(id: "unranked-late", year: 2001),
            makeEvent(id: "unranked-early", year: 1500),
            makeEvent(id: "somber-top", year: 1950, tone: .somber, category: .science)
        ]
        let rank = ["somber-top": 0, "headline": 1, "second": 2, "old": 3]
        XCTAssertEqual(
            DataLoader.feedOrdered(events, rank: rank).map(\.id),
            ["somber-top", "headline", "second", "old", "unranked-early", "unranked-late"]
        )
        // The ambient pick applies the balanced tone policy before ranking.
        XCTAssertEqual(DataLoader.displayEvent(month: 7, day: 10, from: events, feedRank: rank)?.id, "headline")
    }

    func testFeedRankDecodesAndToleratesBadData() {
        let json = #"{"version": 1, "days": {"07-10": ["a", "b"], "07-11": ["c"]}}"#
        XCTAssertEqual(DataLoader.feedRank(from: Data(json.utf8)), ["a": 0, "b": 1, "c": 0])
        XCTAssertTrue(DataLoader.feedRank(from: Data("not json".utf8)).isEmpty)
    }

    func testBundledFeedOrderRanksEveryBundledEvent() async {
        let result = await DataLoader.loadEvents()
        let rank = await DataLoader.loadFeedRank()
        XCTAssertEqual(rank.count, result.events.count)
        XCTAssertTrue(result.events.allSatisfy { rank[$0.id] != nil })
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

// MARK: - Hero image URLs

final class ImageURLTests: XCTestCase {
    private let retired = "https://upload.wikimedia.org/wikipedia/commons/thumb/7/72/Turgenev_by_Repin.jpg/640px-Turgenev_by_Repin.jpg"
    private let served = "https://upload.wikimedia.org/wikipedia/commons/thumb/7/72/Turgenev_by_Repin.jpg/960px-Turgenev_by_Repin.jpg"

    func testRetiredWikimediaWidthIsMappedToServedWidth() {
        XCTAssertEqual(makeEvent(imageURL: retired).imageURL?.absoluteString, served)
        XCTAssertEqual(HistoricalEvent.servedWikimediaThumbnailURLString(retired.replacingOccurrences(of: "640px", with: "800px")), served)
    }

    func testServedWidthsOriginalsAndOtherHostsAreLeftAlone() {
        XCTAssertEqual(makeEvent(imageURL: served).imageURL?.absoluteString, served)
        let small = served.replacingOccurrences(of: "960px", with: "330px")
        XCTAssertEqual(makeEvent(imageURL: small).imageURL?.absoluteString, small)
        let original = "https://upload.wikimedia.org/wikipedia/commons/7/72/Turgenev_by_Repin.jpg"
        XCTAssertEqual(makeEvent(imageURL: original).imageURL?.absoluteString, original)
        let other = "https://example.com/thumb/640px-photo.jpg"
        XCTAssertEqual(makeEvent(imageURL: other).imageURL?.absoluteString, other)
        XCTAssertNil(makeEvent(imageURL: nil).imageURL)
    }
}

// MARK: - Detail screen copy

final class EntryCopyTests: XCTestCase {
    private func entry(
        summary: String,
        detail: String,
        deepDive: String? = nil,
        whyItMatters: String? = nil,
        contextLine: String = "Fixture context line."
    ) -> HistoricalEvent {
        HistoricalEvent(
            id: UUID().uuidString, month: 7, day: 10, year: 1900, title: "Fixture",
            summary: summary, contextLine: contextLine, detail: detail,
            category: .science, tone: .balanced, source: "https://example.com",
            deepDive: deepDive, whyItMatters: whyItMatters
        )
    }

    func testDistinctBlocksAreAllKept() {
        let copy = entry(
            summary: "A lens was ground.",
            detail: "The workshop spent a winter on it.",
            deepDive: "Decades later the design was copied across Europe.",
            whyItMatters: "It made distant things measurable."
        ).entryCopy()
        XCTAssertEqual(copy, EntryCopy(
            lead: "A lens was ground.",
            body: "The workshop spent a winter on it.",
            whyItMatters: "It made distant things measurable.",
            deeperStory: "Decades later the design was copied across Europe."
        ))
    }

    func testRepeatedBodyAndDeeperStoryAreHidden() {
        let text = "A lens was ground in the workshop."
        let copy = entry(summary: text, detail: text + " ", deepDive: text).entryCopy()
        XCTAssertEqual(copy.lead, text)
        XCTAssertNil(copy.body)
        XCTAssertNil(copy.deeperStory)
    }

    func testBodyThatOpensWithTheLeadShowsOnlyWhatFollows() {
        let copy = entry(
            summary: "A lens was ground.",
            detail: "A lens was ground. The workshop spent a winter on it.",
            deepDive: "A lens was ground. The workshop spent a winter on it. Decades later the design was copied across Europe."
        ).entryCopy()
        XCTAssertEqual(copy.lead, "A lens was ground.")
        XCTAssertEqual(copy.body, "The workshop spent a winter on it.")
        XCTAssertEqual(copy.deeperStory, "Decades later the design was copied across Europe.")
    }

    func testClippedSummaryIsReplacedByTheFullFirstSentence() {
        let copy = entry(
            summary: "A judge enjoins administrators from hindering the admission",
            detail: "A judge enjoins administrators from hindering the admission after two rulings. The campus stayed tense for weeks."
        ).entryCopy()
        XCTAssertEqual(copy.lead, "A judge enjoins administrators from hindering the admission after two rulings.")
        XCTAssertEqual(copy.body, "The campus stayed tense for weeks.")
    }

    func testShortTailStaysAttachedToTheLead() {
        let copy = entry(
            summary: "Families read the poem A Visit from St.",
            detail: "Families read the poem A Visit from St. Nicholas."
        ).entryCopy()
        XCTAssertEqual(copy.lead, "Families read the poem A Visit from St. Nicholas.")
        XCTAssertNil(copy.body)
    }

    func testEditorialProcessNotesAreRemoved() {
        let copy = entry(
            summary: "China conducts its first thermonuclear test.",
            detail: "The device was dropped from an aircraft. The repaired wording says conducted rather than announced.",
            deepDive: "This entry is drawn from example.org; the date reflects the recorded civil date.",
            whyItMatters: "It broadens the app beyond politics with source-backed coverage."
        ).entryCopy()
        XCTAssertEqual(copy.body, "The device was dropped from an aircraft.")
        XCTAssertNil(copy.deeperStory)
        XCTAssertNil(copy.whyItMatters)
        XCTAssertFalse(EntryText.isEditorialNote("The presidential candidate set a record for turnout."))
    }

    func testGenericAndRepeatedNotesAreHidden() {
        let filler = "Even a small dated note can reopen the texture of an era."
        let events = (0..<3).map { _ in entry(summary: "S.", detail: "D.", whyItMatters: filler) }
            + [entry(summary: "S.", detail: "D.", whyItMatters: "A specific consequence followed.")]
        let generic = HistoricalEvent.genericNotes(in: events)
        XCTAssertEqual(generic, [EntryText.key(filler)])
        XCTAssertNil(events[0].entryCopy(genericNotes: generic).whyItMatters)
        XCTAssertEqual(events[3].entryCopy(genericNotes: generic).whyItMatters, "A specific consequence followed.")
        // A note that only repeats the italic context line is hidden too.
        let echo = entry(summary: "S.", detail: "D.", whyItMatters: "Fixture context line").entryCopy()
        XCTAssertNil(echo.whyItMatters)
    }

    func testBundledCorpusNeverShowsARepeatedOrInternalBlock() async {
        let events = await DataLoader.loadEvents().events
        let generic = HistoricalEvent.genericNotes(in: events)
        for event in events {
            let copy = event.entryCopy(genericNotes: generic)
            XCTAssertFalse(copy.lead.isEmpty, event.id)
            let blocks = [copy.body, copy.whyItMatters, copy.deeperStory].compactMap { $0 }
            let keys = ([copy.lead] + blocks).map(EntryText.key)
            XCTAssertEqual(Set(keys).count, keys.count, "repeated block in \(event.id)")
            XCTAssertFalse(blocks.contains(where: EntryText.isEditorialNote), "internal note in \(event.id)")
        }
    }
}

// MARK: - Widget dates and ranked highlights

final class WidgetDayTests: XCTestCase {
    private let zone = TimeZone(identifier: "America/New_York")!

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testKeepsEditorialLeadAndCapsRoundupAtThree() {
        let events = [makeEvent(id: "lead", year: 2000), makeEvent(id: "second", year: 1800),
                      makeEvent(id: "third"), makeEvent(id: "fourth")]
        let days = DataLoader.widgetDays(from: events, startingAt: date(2026, 7, 10), timeZone: zone)
        XCTAssertEqual(days.first?.events.map(\.id), ["lead", "second", "third"])
    }

    func testMissingDayClearsPreviousHistoryInsteadOfUsingAnotherDate() {
        let days = DataLoader.widgetDays(from: [makeEvent()], startingAt: date(2026, 7, 9), timeZone: zone)
        XCTAssertEqual(days.count, 3)
        XCTAssertTrue(days[0].events.isEmpty)
        XCTAssertEqual(days[1].events.count, 1)
        XCTAssertTrue(days[2].events.isEmpty)
    }

    func testMidnightRolloverAcrossBothDaylightSavingChanges() {
        for (month, day, hours) in [(3, 8, 23), (11, 1, 25)] {
            let now = date(2026, month, day - 1)
            let days = DataLoader.widgetDays(from: [], startingAt: now, timeZone: zone)
            XCTAssertEqual(days[0].date, now)
            XCTAssertEqual(days[1].date, date(2026, month, day, hour: 0))
            XCTAssertEqual(days[2].date, date(2026, month, day + 1, hour: 0))
            XCTAssertEqual(days[2].date.timeIntervalSince(days[1].date), Double(hours * 3600))
        }
    }

    func testLeapDayAndYearBoundaryUseTheCorrectRecords() {
        let leap = DataLoader.widgetDays(from: [makeEvent(id: "leap", month: 2, day: 29)],
                                        startingAt: date(2028, 2, 28), timeZone: zone)
        XCTAssertEqual(leap[1].events.map(\.id), ["leap"])
        let year = DataLoader.widgetDays(from: [makeEvent(id: "new-year", month: 1, day: 1)],
                                        startingAt: date(2026, 12, 31), timeZone: zone)
        XCTAssertEqual(year[1].events.map(\.id), ["new-year"])
        XCTAssertEqual(year[1].date, date(2027, 1, 1, hour: 0))
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
