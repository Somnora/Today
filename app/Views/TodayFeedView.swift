import SwiftUI

struct TodayFeedView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var preferences: UserPreferences

    private var events: [HistoricalEvent] {
        dataStore.eventsForToday(tonePreference: preferences.currentTonePreference)
    }

    private var metrics: ReadingMetrics {
        ReadingMetrics(density: preferences.currentReadingDensity)
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
        }
    }

    private var paperBackground: some View {
        ZStack {
            Color("BackgroundWarm")

            LinearGradient(
                colors: [
                    Color("AccentWarm").opacity(0.06),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    Color("AccentWarm").opacity(0.04)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: metrics.todayHeaderOuterSpacing) {
            VStack(alignment: .leading, spacing: metrics.todayHeaderInnerSpacing) {
                masthead

                Text("Today")
                    .font(.system(size: metrics.rootTitleSize, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("TextPrimary"))
                    .kerning(-0.6)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(todayDateString)  ·  \(countLabel)")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(Color("TextSecondary"))

                    Text(preferences.currentTonePreference.editorialLabel)
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(Color("TextTertiary"))
                }
            }

            morningNote
        }
    }

    private var masthead: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color("TextTertiary").opacity(0.45))
                .frame(height: 0.6)

            Text("TODAY IN TIME · ALMANAC")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(2.2)
                .foregroundStyle(Color("AccentWarm"))
                .fixedSize()

            Rectangle()
                .fill(Color("TextTertiary").opacity(0.45))
                .frame(height: 0.6)
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if dataStore.isLoading {
            loadingState
        } else if let error = dataStore.error, dataStore.allEvents.isEmpty {
            errorState(error)
        } else if events.isEmpty {
            emptyState
        } else {
            VStack(spacing: 18) {
                if let loadIssue = dataStore.loadIssue {
                    collectionNotice(loadIssue)
                }

                LazyVStack(spacing: 18) {
                    ForEach(events) { event in
                        NavigationLink(value: event) {
                            EventCardView(event: event)
                        }
                        .buttonStyle(.plain)
                    }

                    closingRule
                }
            }
            .navigationDestination(for: HistoricalEvent.self) { event in
                EventDetailView(event: event)
                    .toolbar(.hidden, for: .tabBar)
            }
            .animation(.snappy(duration: 0.28), value: events)
        }
    }

    private var closingRule: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.25))
                    .frame(width: 36, height: 0.6)

                Image(systemName: "diamond.fill")
                    .font(.system(size: 5, weight: .regular))
                    .foregroundStyle(Color("AccentWarm").opacity(0.65))

                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.25))
                    .frame(width: 36, height: 0.6)
            }

            VStack(spacing: 4) {
                Text("That's today's record")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(Color("TextSecondary"))

                Text("A new edition arrives each morning.")
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color("TextTertiary"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
    }

    private var morningNote: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sunrise")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color("AccentWarm"))

                Text("MORNING EDITION")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(Color("TextPrimary"))

                Spacer()

                Text("№ \(editionNumber)")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(Color("TextTertiary"))
                    .tracking(0.5)
            }

            Text("Open a card, follow the thread, and let one strange or beautiful detail change the shape of the day.")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(Color("TextSecondary"))
                .lineSpacing(4)
        }
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color("CardBackground"))

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color("AccentWarm").opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.30),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 200
                        )
                    )
                    .blendMode(.plusLighter)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color("AccentWarm").opacity(0.22), lineWidth: 0.6)
        )
        .shadow(color: Color("AccentWarm").opacity(0.10), radius: 14, x: 0, y: 6)
    }

    private var loadingState: some View {
        VStack(spacing: 18) {
            stateOrnament

            ProgressView()
                .tint(Color("AccentWarm"))
                .scaleEffect(0.9)

            VStack(spacing: 6) {
                Text("Gathering today’s notes")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("TextPrimary"))

                Text("The archive is opening.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
        .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color("AccentWarm").opacity(0.14), lineWidth: 0.6)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            stateOrnament

            ZStack {
                Circle()
                    .fill(Color("AccentWarm").opacity(0.10))
                    .frame(width: 72, height: 72)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Color("AccentWarm"))
            }

            VStack(spacing: 8) {
                Text("A quiet page in the almanac")
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("TextPrimary"))
                    .kerning(-0.2)

                Text("No entries for \(todayDateString) yet. Wander to another date in Explore, or widen the lens in Preferences.")
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

    private var stateOrnament: some View {
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
    }

    private func errorState(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color("AccentWarm"))

            Text("The archive needs attention")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Color("TextPrimary"))

            Text(error.localizedDescription)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func collectionNotice(_ issue: EventLoadIssue) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color("AccentWarm"))

            Text(issue.localizedDescription)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(Color("TextSecondary"))
                .lineSpacing(3)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color("AccentWarm").opacity(0.12), lineWidth: 1)
        )
    }

    private var countLabel: String {
        if dataStore.isLoading {
            return "loading"
        }

        return "\(events.count) \(events.count == 1 ? "moment" : "moments")"
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private var editionNumber: String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return String(format: "%03d", day)
    }
}

#Preview {
    TodayFeedView()
        .environmentObject(DataStore())
        .environmentObject(UserPreferences())
        .environmentObject(ThumbsStore())
}
