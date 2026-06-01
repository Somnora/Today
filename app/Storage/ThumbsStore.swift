import Foundation
import SwiftUI

/// Manages thumbs up/down reactions for events
class ThumbsStore: ObservableObject {
    @AppStorage("eventReactions") private var reactionsData: String = "{}"

    private var reactions: [String: Reaction] = [:]

    init() {
        loadReactions()
    }

    /// Get reaction for an event
    func reactionFor(eventID: String) -> Reaction? {
        reactions[eventID]
    }

    /// Set reaction for an event
    func setReaction(_ reaction: Reaction, for eventID: String) {
        reactions[eventID] = reaction
        saveReactions()
        objectWillChange.send()
    }

    /// Remove reaction for an event
    func removeReaction(for eventID: String) {
        reactions.removeValue(forKey: eventID)
        saveReactions()
        objectWillChange.send()
    }

    /// Toggle thumbs up
    func toggleThumbsUp(for eventID: String) {
        if reactions[eventID] == .thumbsUp {
            removeReaction(for: eventID)
        } else {
            setReaction(.thumbsUp, for: eventID)
        }
    }

    /// Toggle thumbs down
    func toggleThumbsDown(for eventID: String) {
        if reactions[eventID] == .thumbsDown {
            removeReaction(for: eventID)
        } else {
            setReaction(.thumbsDown, for: eventID)
        }
    }

    private func loadReactions() {
        guard let data = reactionsData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Reaction].self, from: data) else {
            return
        }
        reactions = decoded
    }

    private func saveReactions() {
        guard let data = try? JSONEncoder().encode(reactions),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        reactionsData = string
    }
}

enum Reaction: String, Codable {
    case thumbsUp = "up"
    case thumbsDown = "down"
}
