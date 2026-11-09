import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var habitStore: HabitStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var todayOpenRequest = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayFeedView(openTodayRequest: todayOpenRequest)
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
        .onReceive(NotificationRouter.shared.$pendingEventID) { eventID in
            if eventID != nil {
                selectedTab = 0
            }
        }
        .task {
            await dataStore.loadEvents()
            await refreshMorningNotifications()
            #if DEBUG
            applyDebugLaunchOptions()
            await printDebugNotificationReport()
            #endif
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await refreshMorningNotifications()
                }
            }
        }
        .onChange(of: habitStore.state.readDays.last) { _, _ in
            // A read moves the streak reminder to tomorrow morning.
            Task {
                await refreshMorningNotifications()
            }
        }
    }

    /// Keeps the Morning Edition schedule sliding forward and in step with
    /// the reader's delivery time and reading streak.
    private func refreshMorningNotifications() async {
        await NotificationScheduler.refresh(
            enabled: preferences.morningNotificationsEnabled,
            events: dataStore.allEvents,
            feedRank: dataStore.feedRank,
            deliveryMinutes: preferences.morningNotificationMinutes,
            streak: habitStore.streak()
        )
    }

    #if DEBUG
    /// Visual QA switches, read from launch arguments (for example
    /// `-debugTab 3` or `-debugOpenEvent <event id>`), so a headless
    /// simulator can be pointed at a screen without taps.
    private func applyDebugLaunchOptions() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "debugTab") != nil {
            selectedTab = min(max(defaults.integer(forKey: "debugTab"), 0), 3)
        }
        if let eventID = defaults.string(forKey: "debugOpenEvent"), !eventID.isEmpty {
            NotificationRouter.shared.pendingEventID = eventID
        }
    }

    /// `-debugNotificationReport YES` takes provisional authorization, which
    /// needs no permission dialog, refreshes the Morning Edition with the
    /// stored settings and reports what is pending, so the real schedule can
    /// be read back from a headless simulator.
    private func printDebugNotificationReport() async {
        guard UserDefaults.standard.bool(forKey: "debugNotificationReport") else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.provisional, .alert, .sound])
        await refreshMorningNotifications()
        let lines = await NotificationScheduler.pendingReport()
        let report = (["count=\(lines.count)"] + lines).joined(separator: "\n") + "\n"
        print(report)
        // Also left in the app's temporary directory, where a headless run
        // can read it without holding the launch console open.
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("notification-report.txt")
        try? report.write(to: file, atomically: true, encoding: .utf8)
    }
    #endif

    private func handleDeepLink(_ url: URL) {
        if url.absoluteString == "today://today" {
            selectedTab = 0
            todayOpenRequest &+= 1
            return
        }

        guard url.scheme?.lowercased() == "today" else { return }
        switch url.host?.lowercased() {
        case "today", nil:
            selectedTab = 0
            todayOpenRequest &+= 1
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
        .environmentObject(HabitStore())
}
