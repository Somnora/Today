import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var preferences: UserPreferences
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayFeedView()
                .tabItem {
                    Label("Today", systemImage: "calendar")
                }
                .tag(0)

            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "magnifyingglass")
                }
                .tag(1)

            SavedView()
                .tabItem {
                    Label("Saved", systemImage: "bookmark")
                }
                .tag(2)

            PreferencesView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .accentColor(Color("AccentWarm"))
        .onOpenURL(perform: handleDeepLink)
        .task {
            await dataStore.loadEvents()
            await refreshMorningNotifications()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await refreshMorningNotifications()
                }
            }
        }
    }

    /// Keeps the 7-day Morning Edition window sliding forward.
    private func refreshMorningNotifications() async {
        await NotificationScheduler.refresh(
            enabled: preferences.morningNotificationsEnabled,
            events: dataStore.allEvents
        )
    }

    private func handleDeepLink(_ url: URL) {
        if url.absoluteString == "today://today" {
            selectedTab = 0
            return
        }

        guard url.scheme?.lowercased() == "today" else { return }
        switch url.host?.lowercased() {
        case "today", nil:
            selectedTab = 0
        case "explore":
            selectedTab = 1
        case "saved", "bookmarks":
            selectedTab = 2
        case "preferences", "settings":
            selectedTab = 3
        default:
            break
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataStore())
        .environmentObject(UserPreferences())
        .environmentObject(ThumbsStore())
        .environmentObject(SavedStore())
}
