import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var preferences: UserPreferences

    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedDay: Int = Calendar.current.component(.day, from: Date())
    @State private var selectedCategory: EventCategory?

    private var events: [HistoricalEvent] {
        dataStore.eventsFor(
            month: selectedMonth,
            day: selectedDay,
            tonePreference: preferences.currentTonePreference,
            category: selectedCategory
        )
    }

    private var metrics: ReadingMetrics {
        ReadingMetrics(density: preferences.currentReadingDensity)
    }

    private var suggestedDates: [DateSuggestion] {
        let uniqueDates = Dictionary(grouping: dataStore.allEvents) { event in
            DateSuggestion(month: event.month, day: event.day)
        }
        .keys

        return uniqueDates
            .sorted { left, right in
                forwardDistance(to: left) < forwardDistance(to: right)
            }
            .filter { $0.month != selectedMonth || $0.day != selectedDay }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: metrics.rootStackSpacing) {
                    headerSection
                    dateJumpCard
                    categoryRail
                    resultsSection
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
            .onChange(of: selectedMonth) { _, _ in
                selectedDay = min(selectedDay, daysInSelectedMonth)
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

                Text("FROM THE ARCHIVE")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(2.0)
                    .foregroundStyle(Color("AccentWarm"))

                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.18))
                    .frame(height: 0.6)
            }

            Text("Explore")
                .font(.system(size: metrics.rootTitleSize, weight: .semibold, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
                .kerning(-0.6)

            Text("Wander any day in the almanac.")
                .font(.system(size: metrics.rootSubtitleSize, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    private var dateJumpCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wander to another date")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
                .kerning(-0.2)

            Text("See what gathers around a given day, then narrow the lens if you like.")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(Color("TextSecondary"))
                .lineSpacing(4)

            HStack(spacing: 12) {
                selectorMenu(
                    title: Calendar.current.monthSymbols[selectedMonth - 1],
                    options: Array(1...12),
                    formatter: { Calendar.current.monthSymbols[$0 - 1] },
                    selection: $selectedMonth
                )

                selectorMenu(
                    title: "\(selectedDay)",
                    options: Array(1...daysInSelectedMonth),
                    formatter: { "\($0)" },
                    selection: $selectedDay
                )
            }

            Text("\(events.count) \(events.count == 1 ? "piece" : "pieces") for this date")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color("TextSecondary"))
        }
        .padding(22)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color("CardBackground"))

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color("AccentWarm").opacity(0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 220
                        )
                    )
                    .blendMode(.plusLighter)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color("AccentWarm").opacity(0.20), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
        .shadow(color: Color("AccentWarm").opacity(0.12), radius: 18, x: 0, y: 10)
    }

    private var categoryRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Narrow by category")
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundStyle(Color("TextPrimary"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    categoryChip(title: "All", systemImage: "square.grid.2x2", selected: selectedCategory == nil) {
                        selectedCategory = nil
                    }

                    ForEach(dataStore.availableCategories) { category in
                        categoryChip(title: category.displayName, systemImage: category.icon, selected: selectedCategory == category) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var resultsSection: some View {
        Group {
            if events.isEmpty {
                VStack(spacing: 16) {
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
                            .fill(Color("AccentWarm").opacity(0.08))
                            .frame(width: 64, height: 64)

                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(Color("AccentWarm"))
                    }

                    VStack(spacing: 6) {
                        Text("Nothing surfaced here yet")
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                            .foregroundStyle(Color("TextPrimary"))

                        Text("Try another date, or let the category rail breathe a little wider.")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundStyle(Color("TextSecondary"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    if !suggestedDates.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(suggestedDates) { suggestion in
                                Button(suggestion.shortLabel) {
                                    selectedMonth = suggestion.month
                                    selectedDay = suggestion.day
                                    selectedCategory = nil
                                }
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color("AccentWarm"))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(Color("AccentWarm").opacity(0.10), in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color("AccentWarm").opacity(0.22), lineWidth: 0.5)
                                )
                            }
                        }
                        .padding(.top, 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color("CardBackground"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color("AccentWarm").opacity(0.14), lineWidth: 0.6)
                )
                .shadow(color: Color("AccentWarm").opacity(0.08), radius: 14, x: 0, y: 6)
            } else {
                LazyVStack(spacing: 18) {
                    ForEach(events) { event in
                        NavigationLink(value: event) {
                            EventCardView(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func selectorMenu(title: String, options: [Int], formatter: @escaping (Int) -> String, selection: Binding<Int>) -> some View {
        Menu {
            ForEach(options, id: \.self) { value in
                Button(formatter(value)) {
                    selection.wrappedValue = value
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color("AccentWarm"))
            }
            .font(.system(size: 15, weight: .medium, design: .serif))
            .foregroundStyle(Color("TextPrimary"))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color("BackgroundWarm"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color("AccentWarm").opacity(0.22), lineWidth: 0.6)
            )
            .shadow(color: Color("AccentWarm").opacity(0.06), radius: 6, x: 0, y: 3)
        }
    }

    private func categoryChip(title: String, systemImage: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? Color.white : Color("TextSecondary"))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            selected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Color("AccentWarm"),
                                        Color("AccentWarm").opacity(0.85)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            : AnyShapeStyle(Color("CardBackground"))
                        )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            selected ? Color.clear : Color("AccentWarm").opacity(0.16),
                            lineWidth: 0.6
                        )
                )
                .shadow(
                    color: selected ? Color("AccentWarm").opacity(0.30) : Color.black.opacity(0.04),
                    radius: selected ? 8 : 1,
                    x: 0,
                    y: selected ? 4 : 1
                )
        }
        .buttonStyle(.plain)
    }

    private var daysInSelectedMonth: Int {
        var components = DateComponents()
        components.year = Calendar.current.component(.year, from: Date())
        components.month = selectedMonth
        components.day = 1

        guard let date = Calendar.current.date(from: components),
              let range = Calendar.current.range(of: .day, in: .month, for: date) else {
            return 31
        }

        return range.count
    }

    private func forwardDistance(to suggestion: DateSuggestion) -> Int {
        let selectedOrdinal = selectedMonth * 32 + selectedDay
        let suggestionOrdinal = suggestion.month * 32 + suggestion.day
        let distance = suggestionOrdinal - selectedOrdinal
        return distance >= 0 ? distance : distance + (12 * 32)
    }
}

private struct DateSuggestion: Hashable, Identifiable {
    let month: Int
    let day: Int

    var id: String {
        "\(month)-\(day)"
    }

    var shortLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        var components = DateComponents()
        components.year = 2026
        components.month = month
        components.day = day

        guard let date = Calendar.current.date(from: components) else {
            return "\(month)/\(day)"
        }

        return formatter.string(from: date)
    }
}

#Preview {
    ExploreView()
        .environmentObject(DataStore())
        .environmentObject(UserPreferences())
        .environmentObject(ThumbsStore())
}
