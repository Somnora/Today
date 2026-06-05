import Foundation
import SwiftUI

@MainActor
class ThumbsStore: ObservableObject {
    @AppStorage("eventReactions") private var reactionsData: String = "{}"
    @Published private(set) var reactions: [String: Reaction] = [:]

    init() {
        loadReactions()
    }

    func reactionFor(eventID: String) -> Reaction? {
        guard let eventID = normalizedEventID(eventID) else { return nil }
        return reactions[eventID]
    }

    func setReaction(_ reaction: Reaction, for eventID: String) {
        guard let eventID = normalizedEventID(eventID) else { return }
        reactions[eventID] = reaction
        saveReactions()
    }

    func removeReaction(for eventID: String) {
        guard let eventID = normalizedEventID(eventID) else { return }
        reactions.removeValue(forKey: eventID)
        saveReactions()
    }

    func toggleThumbsUp(for eventID: String) {
        if reactionFor(eventID: eventID) == .thumbsUp {
            removeReaction(for: eventID)
        } else {
            setReaction(.thumbsUp, for: eventID)
        }
    }

    func toggleThumbsDown(for eventID: String) {
        if reactionFor(eventID: eventID) == .thumbsDown {
            removeReaction(for: eventID)
        } else {
            setReaction(.thumbsDown, for: eventID)
        }
    }

    private func loadReactions() {
        guard let data = reactionsData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Reaction].self, from: data) else {
            reactions = [:]
            saveReactions()
            return
        }

        reactions = decoded.reduce(into: [:]) { cleaned, pair in
            guard let eventID = normalizedEventID(pair.key) else { return }
            cleaned[eventID] = pair.value
        }
        saveReactions()
    }

    private func saveReactions() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        guard let data = try? encoder.encode(reactions),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        reactionsData = string
    }

    private func normalizedEventID(_ eventID: String) -> String? {
        let trimmed = eventID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

enum Reaction: String, Codable {
    case thumbsUp = "up"
    case thumbsDown = "down"
}
