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

    func testQuizDaysAreFridayThroughSunday() {
        XCTAssertTrue(QuizEngine.isQuizDay(date(2026, 7, 10)))   // Friday
        XCTAssertTrue(QuizEngine.isQuizDay(date(2026, 7, 11)))   // Saturday
        XCTAssertTrue(QuizEngine.isQuizDay(date(2026, 7, 12)))   // Sunday
        XCTAssertFalse(QuizEngine.isQuizDay(date(2026, 7, 7)))   // Tuesday
        XCTAssertFalse(QuizEngine.isQuizDay(date(2026, 7, 9)))   // Thursday
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

// MARK: - Daily question

final class DailyQuestionTests: XCTestCase {
    private static let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testSameDayAlwaysYieldsTheSameQuestion() {
        let corpus = makeQuizCorpus()
        let morning = QuizEngine.dailyQuestion(for: date(2026, 7, 10), events: corpus, calendar: Self.calendar)
        let shuffled = QuizEngine.dailyQuestion(for: date(2026, 7, 10), events: corpus.shuffled(), calendar: Self.calendar)
        XCTAssertNotNil(morning)
        XCTAssertEqual(morning, shuffled)
    }

    func testQuestionsChangeFromDayToDayAndRotateShape() {
        let corpus = makeQuizCorpus()
        let week = (10...16).compactMap { QuizEngine.dailyQuestion(for: date(2026, 7, $0), events: corpus, calendar: Self.calendar) }
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(Set(week.map { $0.prompt + "|" + $0.options.joined() }).count, 7)
        XCTAssertGreaterThanOrEqual(Set(week.map(\.kicker)).count, 2)
    }

    func testQuestionIsWellFormedAndNeverAboutTodaysOwnDate() throws {
        let corpus = makeQuizCorpus()
        let byID = Dictionary(uniqueKeysWithValues: corpus.map { ($0.id, $0) })
        for day in 1...28 {
            let question = try XCTUnwrap(QuizEngine.dailyQuestion(for: date(2026, 7, day), events: corpus, calendar: Self.calendar))
            XCTAssertEqual(Set(question.options).count, question.options.count)
            XCTAssertTrue(question.options.indices.contains(question.correctIndex))
            XCTAssertFalse(question.note.isEmpty)
            let subject = try XCTUnwrap(question.eventID.flatMap { byID[$0] })
            XCTAssertFalse(subject.matches(month: 7, day: day), "day \(day) asks about its own date")
        }
    }

    func testThinCatalogYieldsNoQuestion() {
        XCTAssertNil(QuizEngine.dailyQuestion(for: date(2026, 7, 10), events: Array(makeQuizCorpus().prefix(20)), calendar: Self.calendar))
    }
}

// MARK: - Reading streak

final class ReadingStreakTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testDayKeyUsesTheLocalCalendarDay() {
        XCTAssertEqual(ReadingStreak.dayKey(for: date(2026, 3, 8, hour: 23), calendar: calendar), "2026-03-08")
        XCTAssertEqual(ReadingStreak.dayKey(for: date(2027, 1, 1, hour: 0), calendar: calendar), "2027-01-01")
    }

    func testStreakCountsConsecutiveDaysAndSurvivesUntilTheDayEnds() {
        var state = HabitState()
        XCTAssertEqual(state.streak(asOf: date(2026, 7, 10), calendar: calendar), ReadingStreakStatus(count: 0, readToday: false, longest: 0))

        XCTAssertTrue(state.recordRead(on: date(2026, 7, 8), calendar: calendar))
        XCTAssertTrue(state.recordRead(on: date(2026, 7, 9), calendar: calendar))
        // Not read yet on the 10th: yesterday's run is still alive.
        XCTAssertEqual(state.streak(asOf: date(2026, 7, 10), calendar: calendar), ReadingStreakStatus(count: 2, readToday: false, longest: 2))

        XCTAssertTrue(state.recordRead(on: date(2026, 7, 10), calendar: calendar))
        XCTAssertFalse(state.recordRead(on: date(2026, 7, 10, hour: 22), calendar: calendar))
        XCTAssertEqual(state.streak(asOf: date(2026, 7, 10), calendar: calendar), ReadingStreakStatus(count: 3, readToday: true, longest: 3))
    }

    func testAMissedDayResetsTheStreakButKeepsTheLongest() {
        var state = HabitState()
        for day in 1...5 { _ = state.recordRead(on: date(2026, 7, day), calendar: calendar) }
        // Nothing on the 6th; by the 7th the run is over.
        XCTAssertEqual(state.streak(asOf: date(2026, 7, 7), calendar: calendar), ReadingStreakStatus(count: 0, readToday: false, longest: 5))
        _ = state.recordRead(on: date(2026, 7, 7), calendar: calendar)
        XCTAssertEqual(state.streak(asOf: date(2026, 7, 7), calendar: calendar), ReadingStreakStatus(count: 1, readToday: true, longest: 5))
    }

    func testStreakCrossesMonthYearAndDaylightSavingBoundaries() {
        var state = HabitState()
        for (y, m, d) in [(2026, 12, 30), (2026, 12, 31), (2027, 1, 1)] { _ = state.recordRead(on: date(y, m, d), calendar: calendar) }
        XCTAssertEqual(state.streak(asOf: date(2027, 1, 1), calendar: calendar).count, 3)

        var spring = HabitState()
        for day in 7...9 { _ = spring.recordRead(on: date(2026, 3, day, hour: 23), calendar: calendar) }
        XCTAssertEqual(spring.streak(asOf: date(2026, 3, 9, hour: 23), calendar: calendar).count, 3)
    }

    func testOnlyTheFirstAnswerOfADayCounts() {
        var state = HabitState()
        XCTAssertTrue(state.recordAnswer(choice: 2, correct: true, on: date(2026, 7, 10), calendar: calendar))
        XCTAssertFalse(state.recordAnswer(choice: 0, correct: false, on: date(2026, 7, 10, hour: 20), calendar: calendar))
        XCTAssertTrue(state.recordAnswer(choice: 1, correct: false, on: date(2026, 7, 11), calendar: calendar))
        XCTAssertEqual(state.answers["2026-07-10"], DailyAnswer(choice: 2, correct: true))
        XCTAssertEqual(state.questionsAnswered, 2)
        XCTAssertEqual(state.questionsCorrect, 1)
    }

    func testStateSurvivesEncodingAndOldStoredValues() throws {
        var state = HabitState()
        _ = state.recordRead(on: date(2026, 7, 10), calendar: calendar)
        _ = state.recordAnswer(choice: 1, correct: true, on: date(2026, 7, 10), calendar: calendar)
        let decoded = try JSONDecoder().decode(HabitState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded, state)
        XCTAssertEqual(try JSONDecoder().decode(HabitState.self, from: Data("{}".utf8)), HabitState())
        XCTAssertEqual(state.streak(asOf: date(2026, 7, 10), calendar: calendar).summaryLine, "Day 1 of a new reading streak.")
    }
}

// MARK: - Quiz results and streaks

final class MorningEditionPlanTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// One event on every calendar day, leap day included.
    private func makeYearCorpus() -> [HistoricalEvent] {
        let daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return daysInMonth.enumerated().flatMap { index, days in
            (1...days).map { day in
                makeEvent(
                    id: String(format: "day-%02d-%02d", index + 1, day),
                    month: index + 1,
                    day: day,
                    year: 1900,
                    title: "Lead story for \(index + 1)/\(day)"
                )
            }
        }
    }

    private func plan(
        now: Date,
        deliveryMinutes: Int = NotificationScheduler.defaultDeliveryMinutes,
        streak: ReadingStreakStatus? = nil
    ) -> [MorningEditionNotification] {
        NotificationScheduler.plan(
            now: now,
            events: makeYearCorpus(),
            deliveryMinutes: deliveryMinutes,
            streak: streak,
            calendar: calendar
        )
    }

    func testPlanReachesSixtyMorningsAheadAndStaysUnderTheSystemLimit() {
        // 05:00, before the default 08:00 delivery: today still counts.
        let planned = plan(now: date(2026, 12, 20, hour: 5))

        XCTAssertEqual(planned.count, NotificationScheduler.scheduledDayCount)
        XCTAssertEqual(planned.count, 60)
        XCTAssertLessThan(planned.count, NotificationScheduler.pendingNotificationLimit)
        XCTAssertEqual(Set(planned.map(\.identifier)).count, planned.count, "Identifiers must be unique across a year boundary")

        XCTAssertEqual(planned.first?.identifier, "today-morning-2026-12-20")
        XCTAssertEqual(planned.first?.eventID, "day-12-20")
        XCTAssertEqual(planned.first?.title, "Morning Edition · December 20")
        XCTAssertEqual(planned.last?.identifier, "today-morning-2027-2-17")
        XCTAssertEqual(planned.last?.eventID, "day-02-17")

        let fireDates = planned.compactMap { calendar.date(from: $0.fireComponents) }
        XCTAssertEqual(fireDates, fireDates.sorted())
        XCTAssertEqual(fireDates.count, planned.count)
    }

    func testPlanSkipsTodayOnceTheDeliveryTimeHasPassed() {
        let planned = plan(now: date(2026, 11, 9, hour: 8, minute: 1))

        XCTAssertEqual(planned.count, 59)
        XCTAssertEqual(planned.first?.identifier, "today-morning-2026-11-10")
    }

    func testPlanDeliversAtTheChosenTime() {
        let planned = plan(now: date(2026, 11, 9, hour: 6), deliveryMinutes: 6 * 60 + 45)

        XCTAssertEqual(planned.count, 60)
        XCTAssertTrue(planned.allSatisfy { $0.fireComponents.hour == 6 && $0.fireComponents.minute == 45 })

        // An evening reader: 21:30 today is still ahead at 06:00.
        let evening = plan(now: date(2026, 11, 9, hour: 6), deliveryMinutes: 21 * 60 + 30)
        XCTAssertEqual(evening.first?.identifier, "today-morning-2026-11-9")
        XCTAssertEqual(evening.first?.fireComponents.hour, 21)
        XCTAssertEqual(evening.first?.fireComponents.minute, 30)

        // Out-of-range values are clamped rather than producing bad triggers.
        let clamped = plan(now: date(2026, 11, 9, hour: 6), deliveryMinutes: 5_000)
        XCTAssertTrue(clamped.allSatisfy { $0.fireComponents.hour == 23 && $0.fireComponents.minute == 59 })
    }

    func testPlanLeadsWithTheEditorialFeedLead() {
        let old = makeEvent(id: "old", month: 11, day: 10, year: 1500, title: "Old footnote")
        let lead = makeEvent(id: "lead", month: 11, day: 10, year: 1989, title: "Lead headline")
        let planned = NotificationScheduler.plan(
            now: date(2026, 11, 9, hour: 12),
            events: [old, lead],
            feedRank: ["lead": 0, "old": 1],
            calendar: calendar
        )

        XCTAssertEqual(planned.map(\.eventID), ["lead"], "Days without events are skipped")
        XCTAssertEqual(planned.first?.body, "1989 · Lead headline")
    }

    func testStreakReminderAppearsOnlyOnTheMorningTheStreakIsAtStake() {
        // Read today already: the streak next needs tomorrow.
        let readToday = plan(
            now: date(2026, 11, 9, hour: 21),
            streak: ReadingStreakStatus(count: 4, readToday: true, longest: 6)
        )
        XCTAssertEqual(readToday.first?.identifier, "today-morning-2026-11-10")
        XCTAssertEqual(readToday.first?.body, "1900 · Lead story for 11/10\n4 days running. One entry today keeps your reading streak.")
        XCTAssertFalse(readToday.dropFirst().contains { $0.body.contains("reading streak") })

        // Not read yet today, and this morning's edition is still ahead.
        let atStakeToday = plan(
            now: date(2026, 11, 9, hour: 5),
            streak: ReadingStreakStatus(count: 4, readToday: false, longest: 6)
        )
        XCTAssertEqual(atStakeToday.first?.identifier, "today-morning-2026-11-9")
        XCTAssertTrue(atStakeToday.first?.body.hasSuffix("4 days running. One entry today keeps your reading streak.") ?? false)
        XCTAssertFalse(atStakeToday.dropFirst().contains { $0.body.contains("reading streak") })

        // Not read yet today, edition already delivered: nothing left to say.
        let alreadyDelivered = plan(
            now: date(2026, 11, 9, hour: 9),
            streak: ReadingStreakStatus(count: 4, readToday: false, longest: 6)
        )
        XCTAssertFalse(alreadyDelivered.contains { $0.body.contains("reading streak") })
    }

    func testStreakReminderWording() {
        XCTAssertNil(NotificationScheduler.streakLine(streak: nil, dayOffset: 0))
        XCTAssertNil(NotificationScheduler.streakLine(streak: ReadingStreakStatus(count: 0, readToday: false, longest: 3), dayOffset: 0))
        XCTAssertEqual(
            NotificationScheduler.streakLine(streak: ReadingStreakStatus(count: 1, readToday: true, longest: 1), dayOffset: 1),
            "You read yesterday. One entry today makes it two days running."
        )
        XCTAssertNil(NotificationScheduler.streakLine(streak: ReadingStreakStatus(count: 1, readToday: true, longest: 1), dayOffset: 0))
        XCTAssertNil(NotificationScheduler.streakLine(streak: ReadingStreakStatus(count: 9, readToday: true, longest: 9), dayOffset: 2))
    }

    func testFridayEditionsAnnounceTheWeekendQuiz() {
        let planned = plan(now: date(2026, 11, 9, hour: 5))
        let fridays = planned.filter {
            calendar.component(.weekday, from: calendar.date(from: $0.fireComponents)!) == 6
        }

        XCTAssertGreaterThanOrEqual(fridays.count, 8)
        XCTAssertTrue(fridays.allSatisfy { $0.body.hasSuffix("\n" + NotificationScheduler.quizLine) })
        XCTAssertEqual(planned.filter { $0.body.contains(NotificationScheduler.quizLine) }.count, fridays.count)
        XCTAssertTrue(fridays.allSatisfy { QuizEngine.isQuizDay(calendar.date(from: $0.fireComponents)!) })
    }

    func testStreakReminderTakesTheSlotFromTheQuizLine() {
        // Thursday evening, so the morning at stake is a Friday.
        let now = date(2026, 11, 12, hour: 21)
        XCTAssertEqual(calendar.component(.weekday, from: now), 5)

        let planned = plan(now: now, streak: ReadingStreakStatus(count: 2, readToday: true, longest: 2))
        XCTAssertEqual(planned.first?.identifier, "today-morning-2026-11-13")
        XCTAssertTrue(planned.first?.body.contains("2 days running") ?? false)
        XCTAssertFalse(planned.first?.body.contains(NotificationScheduler.quizLine) ?? true)
    }

    func testPlanIsEmptyWithoutEvents() {
        XCTAssertTrue(NotificationScheduler.plan(now: date(2026, 11, 9), events: [], calendar: calendar).isEmpty)
    }
}

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
