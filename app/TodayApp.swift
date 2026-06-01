import SwiftUI

@main
struct TodayApp: App {
    @StateObject private var dataStore = DataStore()
    @StateObject private var preferences = UserPreferences()
    @StateObject private var thumbsStore = ThumbsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(preferences)
                .environmentObject(thumbsStore)
        }
    }
}
