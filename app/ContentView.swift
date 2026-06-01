import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStore: DataStore
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

            PreferencesView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .accentColor(Color("AccentWarm"))
        .task {
            await dataStore.loadEvents()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataStore())
        .environmentObject(UserPreferences())
        .environmentObject(ThumbsStore())
}
