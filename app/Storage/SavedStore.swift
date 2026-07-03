import Foundation
import SwiftUI

@MainActor
class SavedStore: ObservableObject {
    @AppStorage("savedEventIDs") private var savedIDsData: String = "[]"
    @Published private(set) var savedIDs: Set<String> = []

    init() {
        loadSavedIDs()
    }

    func isSaved(_ eventID: String) -> Bool {
        guard let eventID = normalizedEventID(eventID) else { return false }
        return savedIDs.contains(eventID)
    }

    func toggle(_ eventID: String) {
        guard let eventID = normalizedEventID(eventID) else { return }
        if savedIDs.contains(eventID) {
            savedIDs.remove(eventID)
        } else {
            savedIDs.insert(eventID)
        }
        saveIDs()
    }

    private func loadSavedIDs() {
        guard let data = savedIDsData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            savedIDs = []
            return
        }

        savedIDs = Set(decoded.compactMap(normalizedEventID))
    }

    private func saveIDs() {
        let ordered = savedIDs.sorted()
        guard let data = try? JSONEncoder().encode(ordered),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        savedIDsData = string
    }

    private func normalizedEventID(_ eventID: String) -> String? {
        let trimmed = eventID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
