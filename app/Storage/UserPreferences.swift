import Foundation
import SwiftUI

enum ReadingDensity: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case standard = "Standard"
    case comfortable = "Comfortable"

    var id: String { rawValue }
}

/// Manages user preferences and settings
class UserPreferences: ObservableObject {
    @AppStorage("tonePreference") var tonePreference: String = TonePreference.balanced.rawValue
    @AppStorage("readingDensity") var readingDensity: String = ReadingDensity.standard.rawValue
    @AppStorage("morningNotificationsEnabled") var morningNotificationsEnabled: Bool = false

    var currentTonePreference: TonePreference {
        get {
            TonePreference(rawValue: tonePreference) ?? .balanced
        }
        set {
            tonePreference = newValue.rawValue
        }
    }

    var currentReadingDensity: ReadingDensity {
        get {
            ReadingDensity(rawValue: readingDensity) ?? .standard
        }
        set {
            readingDensity = newValue.rawValue
        }
    }
}
