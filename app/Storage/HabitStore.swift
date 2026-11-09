import Foundation
import SwiftUI

/// The reader's answer to one day's question.
struct DailyAnswer: Codable, Equatable {
    let choice: Int
    let correct: Bool
}

/// Where the reading streak stands on a given day.
struct ReadingStreakStatus: Equatable {
    /// Consecutive days with at least one entry read, ending today or, when
    /// today has no read yet, yesterday.
    let count: Int
    let readToday: Bool
    let longest: Int

    /// One line for the Today masthead.
    var summaryLine: String {
        if count == 0 {
            return "Read one entry today to start a reading streak."
        }
        if readToday {
            return count == 1 ? "Day 1 of a new reading streak." : "Day \(count) of your reading streak."
        }
        return "\(count)-day reading streak. Read one entry today to keep it."
    }
}

/// Pure calendar math for the reading streak, kept free of storage so it can
/// be tested directly.
enum ReadingStreak {
    /// Local calendar day as "yyyy-MM-dd". Built from components rather than
    /// a formatter so locale and calendar settings cannot change the key.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Consecutive read days ending on `date`, or on the day before when
    /// `date` itself has no read yet (the streak is still alive until the
    /// day ends).
    static func current(readDays: Set<String>, asOf date: Date, calendar: Calendar = .current) -> (count: Int, readToday: Bool) {
        let readToday = readDays.contains(dayKey(for: date, calendar: calendar))
        var cursor = date
        if !readToday {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return (0, false) }
            cursor = yesterday
        }

        var count = 0
        while readDays.contains(dayKey(for: cursor, calendar: calendar)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return (count, readToday)
    }
}

/// Everything the daily habit loop persists, stored as one JSON value.
struct HabitState: Codable, Equatable {
    var readDays: [String] = []
    var longestStreak = 0
    var answers: [String: DailyAnswer] = [:]
    var questionsAnswered = 0
    var questionsCorrect = 0

    static let readDayLimit = 400
    static let answerLimit = 60

    init() {}

    /// Tolerant decoding: a missing field keeps its default, so the empty
    /// stored value and states written by older builds both load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        readDays = try container.decodeIfPresent([String].self, forKey: .readDays) ?? []
        longestStreak = try container.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        answers = try container.decodeIfPresent([String: DailyAnswer].self, forKey: .answers) ?? [:]
        questionsAnswered = try container.decodeIfPresent(Int.self, forKey: .questionsAnswered) ?? 0
        questionsCorrect = try container.decodeIfPresent(Int.self, forKey: .questionsCorrect) ?? 0
    }

    /// Marks `date` as a day with a read. Returns false when it already was.
    mutating func recordRead(on date: Date, calendar: Calendar = .current) -> Bool {
        let key = ReadingStreak.dayKey(for: date, calendar: calendar)
        guard !readDays.contains(key) else { return false }
        readDays.append(key)
        readDays.sort()
        if readDays.count > Self.readDayLimit {
            readDays.removeFirst(readDays.count - Self.readDayLimit)
        }
        let streak = ReadingStreak.current(readDays: Set(readDays), asOf: date, calendar: calendar).count
        longestStreak = max(longestStreak, streak)
        return true
    }

    /// Records the first answer given on `date`; later answers are ignored.
    mutating func recordAnswer(choice: Int, correct: Bool, on date: Date, calendar: Calendar = .current) -> Bool {
        let key = ReadingStreak.dayKey(for: date, calendar: calendar)
        guard answers[key] == nil else { return false }
        answers[key] = DailyAnswer(choice: choice, correct: correct)
        questionsAnswered += 1
        if correct {
            questionsCorrect += 1
        }
        if answers.count > Self.answerLimit {
            for stale in answers.keys.sorted().prefix(answers.count - Self.answerLimit) {
                answers.removeValue(forKey: stale)
            }
        }
        return true
    }

    func streak(asOf date: Date, calendar: Calendar = .current) -> ReadingStreakStatus {
        let current = ReadingStreak.current(readDays: Set(readDays), asOf: date, calendar: calendar)
        return ReadingStreakStatus(count: current.count, readToday: current.readToday, longest: max(longestStreak, current.count))
    }
}

/// The daily habit loop: which days the reader opened an entry, and how they
/// answered each day's question. Stays on this device.
@MainActor
final class HabitStore: ObservableObject {
    @AppStorage("habitStateV1") private var storedState: String = "{}"
    @Published private(set) var state = HabitState()

    init() {
        if let data = storedState.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(HabitState.self, from: data) {
            state = decoded
        }
    }

    /// Call when the reader opens an entry.
    func recordRead(on date: Date = Date()) {
        var next = state
        if next.recordRead(on: date) {
            state = next
            save()
        }
    }

    func recordAnswer(choice: Int, correct: Bool, on date: Date = Date()) {
        var next = state
        if next.recordAnswer(choice: choice, correct: correct, on: date) {
            state = next
            save()
        }
    }

    func answer(on date: Date) -> DailyAnswer? {
        state.answers[ReadingStreak.dayKey(for: date)]
    }

    func streak(asOf date: Date = Date()) -> ReadingStreakStatus {
        state.streak(asOf: date)
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(state), let encoded = String(data: data, encoding: .utf8) else { return }
        storedState = encoded
    }
}
