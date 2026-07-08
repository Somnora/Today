import SwiftUI

struct SavedView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var savedStore: SavedStore
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    private var metrics: ReadingMetrics {
        ReadingMetrics(density: preferences.currentReadingDensity, typeScale: typeScale)
    }

    private var savedEvents: [HistoricalEvent] {
        dataStore.allEvents
            .filter { savedStore.savedIDs.contains($0.id) }
            .sorted { left, right in
                if left.month != right.month {
                    return left.month < right.month
                }
                if left.day != right.day {
                    return left.day < right.day
                }
                let leftYear = left.year ?? 0
                let rightYear = right.year ?? 0
                if leftYear != rightYear {
                    return leftYear < rightYear
                }
                return left.title < right.title
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: metrics.rootStackSpacing) {
                    headerSection
                    contentSection
                }
                .padding(.horizontal, 20)
                .padding(.top, metrics.rootTopPadding)
                .padding(.bottom, 40)
            }
            .background(paperBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HistoricalEvent.self) { event in
                EventDetailView(event: event)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
    }

    private var paperBackground: some View {
        ZStack {
            Color("BackgroundWarm")

            LinearGradient(
                colors: [
                    Color("AccentWarm").opacity(0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: metrics.archiveHeaderSpacing) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.45))
                    .frame(width: 18, height: 0.8)

                Text("KEPT FOR LATER")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(2.0)
                    .foregroundStyle(Color("AccentWarm"))

                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.18))
                    .frame(height: 0.6)
            }

            Text("Saved")
                .font(.system(size: metrics.rootTitleSize, weight: .semibold, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
                .kerning(-0.6)

            Text(subtitleText)
                .font(.system(size: metrics.rootSubtitleSize, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    private var subtitleText: String {
        if savedEvents.isEmpty {
            return "Entries you bookmark will gather here."
        }
        return "\(savedEvents.count) \(savedEvents.count == 1 ? "entry" : "entries") kept for another read."
    }

    @ViewBuilder
    private var contentSection: some View {
        if savedEvents.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 18) {
                ForEach(savedEvents) { event in
                    NavigationLink(value: event) {
                        EventCardView(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
            .animation(.snappy(duration: 0.28), value: savedEvents)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.30))
                    .frame(width: 24, height: 0.6)

                Image(systemName: "diamond.fill")
                    .font(.system(size: 4))
                    .foregroundStyle(Color("AccentWarm").opacity(0.55))

                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.30))
                    .frame(width: 24, height: 0.6)
            }

            ZStack {
                Circle()
                    .fill(Color("AccentWarm").opacity(0.10))
                    .frame(width: 72, height: 72)

                Image(systemName: "bookmark")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Color("AccentWarm"))
            }

            VStack(spacing: 8) {
                Text("Nothing saved yet")
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("TextPrimary"))
                    .kerning(-0.2)

                Text("Tap the bookmark on any almanac entry and it will keep a place here.")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(Color("TextSecondary"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 28)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color("CardBackground"))

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color("AccentWarm").opacity(0.06),
                                Color.clear
                            ],
                            center: .top,
                            startRadius: 10,
                            endRadius: 220
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color("AccentWarm").opacity(0.16), lineWidth: 0.6)
        )
        .shadow(color: Color("AccentWarm").opacity(0.08), radius: 14, x: 0, y: 6)
    }
}

#Preview {
    SavedView()
        .environmentObject(DataStore())
        .environmentObject(UserPreferences())
        .environmentObject(SavedStore())
        .environmentObject(ThumbsStore())
}
