import SwiftUI

@main
struct TodayApp: App {
    init() {
        NotificationRouter.shared.activate()
    }

    @StateObject private var dataStore = DataStore()
    @StateObject private var preferences = UserPreferences()
    @StateObject private var thumbsStore = ThumbsStore()
    @StateObject private var savedStore = SavedStore()
    @StateObject private var quizStore = QuizStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(preferences)
                .environmentObject(thumbsStore)
                .environmentObject(savedStore)
                .environmentObject(quizStore)
        }
    }
}
