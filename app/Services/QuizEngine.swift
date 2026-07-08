import Foundation

/// One question in the weekly quiz. Options are display-ready strings; the
/// note is revealed after answering.
struct QuizQuestion: Identifiable, Equatable {
    let id: Int
    let kicker: String
    let prompt: String
    let options: [String]
    let correctIndex: Int
    let note: String
}

struct WeeklyQuiz: Identifiable, Equatable {
    let weekKey: String
    let questions: [QuizQuestion]

    var id: String { weekKey }
}

/// Deterministic weekly quiz drawn from the bundled corpus. Seeded by the ISO
/// week, so Friday and Sunday share one quiz and every device generates the
/// same questions from the same catalog.
enum QuizEngine {
    static let questionCount = 5

    static let isoCalendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }()

    static func weekKey(for date: Date) -> String {
        let year = isoCalendar.component(.yearForWeekOfYear, from: date)
        let week = isoCalendar.component(.weekOfYear, from: date)
        return String(format: "%d-W%02d", year, week)
    }

    /// Quiz days are Friday and Sunday.
    static func isQuizDay(_ date: Date) -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-quiz-day") { return true }
        #endif
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 6 || weekday == 1
    }

    /// The Friday of the date's ISO week anchors the "match the date"
    /// question, so Friday and Sunday ask about the same calendar day.
    static func anchorDay(for date: Date) -> MonthDay {
        var components = isoCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 6
        guard let friday = isoCalendar.date(from: components) else {
            let fallback = Calendar.current.dateComponents([.month, .day], from: date)
            return MonthDay(month: fallback.month ?? 1, day: fallback.day ?? 1)
        }
        let monthDay = isoCalendar.dateComponents([.month, .day], from: friday)
        return MonthDay(month: monthDay.month ?? 1, day: monthDay.day ?? 1)
    }

    static func quiz(for date: Date, events: [HistoricalEvent]) -> WeeklyQuiz? {
        let year = isoCalendar.component(.yearForWeekOfYear, from: date)
        let week = isoCalendar.component(.weekOfYear, from: date)
        var rng = SplitMix64(seed: UInt64(max(year, 1)) &* 1_000 &+ UInt64(week))
        let currentYear = Calendar.current.component(.year, from: date)

        // Illustrated, non-somber records with a concrete year are the
        // curated, recognizable slice of the catalog. Many curated titles are
        // truncated blurbs ending in an ellipsis — those read poorly as quiz
        // options, so only whole titles qualify.
        let base = events
            .filter { $0.isPublishable && $0.tone != .somber && $0.year != nil }
            .sorted { $0.id < $1.id }
        let clean = base.filter { !$0.title.hasSuffix("…") && !$0.title.hasSuffix("...") }
        var pool = clean.filter { $0.imageURLString != nil }
        if pool.count < 120 { pool = clean }
        guard pool.count >= 120 else { return nil }

        // Titles carrying a long digit run (years, act numbers) would leak
        // the answer to year-placement and ordering questions.
        let yearSafe = pool.filter {
            $0.title.range(of: #"\d{3}"#, options: .regularExpression) == nil
                && $0.title.count <= 90
                && ($0.year ?? 0) >= 1000
        }
        guard yearSafe.count >= 40 else { return nil }

        var used = Set<String>()
        var questions: [QuizQuestion] = []

        let builders: [(Int, inout SplitMix64) -> QuizQuestion?] = [
            { id, rng in yearQuestion(id: id, pool: yearSafe, used: &used, currentYear: currentYear, rng: &rng) },
            { id, rng in orderQuestion(id: id, pool: yearSafe, used: &used, rng: &rng) },
            { id, rng in dateQuestion(id: id, pool: clean, anchor: anchorDay(for: date), used: &used, rng: &rng) },
            { id, rng in yearQuestion(id: id, pool: yearSafe, used: &used, currentYear: currentYear, rng: &rng) },
            { id, rng in orderQuestion(id: id, pool: yearSafe, used: &used, rng: &rng) }
        ]
        for builder in builders {
            if let question = builder(questions.count, &rng) {
                questions.append(question)
            }
        }
        while questions.count < questionCount,
              let filler = yearQuestion(id: questions.count, pool: yearSafe, used: &used, currentYear: currentYear, rng: &rng) {
            questions.append(filler)
        }
        guard questions.count == questionCount else { return nil }

        return WeeklyQuiz(weekKey: weekKey(for: date), questions: questions)
    }

    // MARK: Question shapes

    private static func yearQuestion(id: Int, pool: [HistoricalEvent], used: inout Set<String>, currentYear: Int, rng: inout SplitMix64) -> QuizQuestion? {
        guard let event = pick(pool, excluding: used, using: &rng),
              let eventYear = event.year else { return nil }
        used.insert(event.id)

        // Older events earn a wider band of plausible distractor years.
        let spread = max(4, min(40, (currentYear - eventYear) / 6))
        var years: Set<Int> = [eventYear]
        var attempts = 0
        while years.count < 4 && attempts < 96 {
            attempts += 1
            let offset = Int.random(in: -spread...spread, using: &rng)
            let candidate = eventYear + offset
            if candidate != eventYear, candidate <= currentYear {
                years.insert(candidate)
            }
        }
        guard years.count == 4 else { return nil }

        let options = years.sorted().map(String.init)
        guard let correctIndex = options.firstIndex(of: String(eventYear)) else { return nil }
        return QuizQuestion(
            id: id,
            kicker: "PLACE THE YEAR",
            prompt: event.title,
            options: options,
            correctIndex: correctIndex,
            note: event.summary
        )
    }

    private static func orderQuestion(id: Int, pool: [HistoricalEvent], used: inout Set<String>, rng: inout SplitMix64) -> QuizQuestion? {
        guard let first = pick(pool, excluding: used, using: &rng),
              let firstYear = first.year else { return nil }
        used.insert(first.id)

        guard let second = pick(pool, excluding: used, using: &rng, where: { candidate in
            guard let candidateYear = candidate.year else { return false }
            let gap = abs(candidateYear - firstYear)
            return gap >= 3 && gap <= 300
        }), let secondYear = second.year else { return nil }
        used.insert(second.id)

        let shown = [first, second].shuffled(using: &rng)
        let earlier = firstYear < secondYear ? first : second
        let later = firstYear < secondYear ? second : first
        guard let correctIndex = shown.firstIndex(of: earlier) else { return nil }
        return QuizQuestion(
            id: id,
            kicker: "WHICH CAME FIRST",
            prompt: "Which of these happened first?",
            options: shown.map(\.title),
            correctIndex: correctIndex,
            note: "\(earlier.title) — \(earlier.yearLabel). \(later.title) — \(later.yearLabel)."
        )
    }

    private static func dateQuestion(id: Int, pool: [HistoricalEvent], anchor: MonthDay, used: inout Set<String>, rng: inout SplitMix64) -> QuizQuestion? {
        let monthName = monthName(for: anchor.month)
        func leaksDate(_ event: HistoricalEvent) -> Bool {
            event.title.localizedCaseInsensitiveContains(monthName)
        }

        guard let correct = pick(pool, excluding: used, using: &rng, where: {
            $0.matches(month: anchor.month, day: anchor.day) && !leaksDate($0)
        }) else { return nil }
        used.insert(correct.id)

        var distractors: [HistoricalEvent] = []
        while distractors.count < 3 {
            guard let candidate = pick(pool, excluding: used, using: &rng, where: {
                !$0.matches(month: anchor.month, day: anchor.day) && !leaksDate($0)
            }) else { return nil }
            used.insert(candidate.id)
            distractors.append(candidate)
        }

        let shown = ([correct] + distractors).shuffled(using: &rng)
        guard let correctIndex = shown.firstIndex(of: correct) else { return nil }
        return QuizQuestion(
            id: id,
            kicker: "MATCH THE DATE",
            prompt: "Which of these happened on \(correct.monthDayString)?",
            options: shown.map(\.title),
            correctIndex: correctIndex,
            note: correct.summary
        )
    }

    // MARK: Helpers

    private static func pick(
        _ pool: [HistoricalEvent],
        excluding used: Set<String>,
        using rng: inout SplitMix64,
        where predicate: (HistoricalEvent) -> Bool = { _ in true }
    ) -> HistoricalEvent? {
        let candidates = pool.filter { !used.contains($0.id) && predicate($0) }
        guard !candidates.isEmpty else { return nil }
        return candidates[Int.random(in: 0..<candidates.count, using: &rng)]
    }

    private static func monthName(for month: Int) -> String {
        let symbols = Calendar.current.monthSymbols
        let index = min(max(month - 1, 0), symbols.count - 1)
        return symbols[index]
    }
}

/// Small deterministic RNG so the same seed always yields the same quiz.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
