import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var dataStore: DataStore

    private var metrics: ReadingMetrics {
        ReadingMetrics(density: preferences.currentReadingDensity)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: metrics.rootStackSpacing) {
                    headerSection
                    toneSection
                    densitySection
                    librarySection
                    aboutSection
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

                Text("EDITORIAL DESK")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(2.0)
                    .foregroundStyle(Color("AccentWarm"))

                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.18))
                    .frame(height: 0.6)
            }

            Text("Preferences")
                .font(.system(size: metrics.rootTitleSize, weight: .semibold, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
                .kerning(-0.6)

            Text("Set the tone of your daily reading.")
                .font(.system(size: metrics.rootSubtitleSize, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Reading Tone")

            VStack(alignment: .leading, spacing: 14) {
                Picker("Mode", selection: Binding(
                    get: { preferences.currentTonePreference },
                    set: { preferences.currentTonePreference = $0 }
                )) {
                    ForEach(TonePreference.allCases, id: \.self) { tone in
                        Text(tone.rawValue).tag(tone)
                    }
                }
                .pickerStyle(.segmented)

                Text(footerText)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color("TextSecondary"))
                    .lineSpacing(3)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(elevatedSurface)
        }
    }

    private var densitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Reading Size")

            VStack(alignment: .leading, spacing: 14) {
                Picker("Reading Size", selection: Binding(
                    get: { preferences.currentReadingDensity },
                    set: { preferences.currentReadingDensity = $0 }
                )) {
                    ForEach(ReadingDensity.allCases) { density in
                        Text(density.rawValue).tag(density)
                    }
                }
                .pickerStyle(.segmented)

                Text(densityFooterText)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color("TextSecondary"))
                    .lineSpacing(3)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(elevatedSurface)
        }
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Library")

            VStack(spacing: 0) {
                statRow(title: "Ready to read", value: "\(dataStore.allEvents.count)", systemImage: "rectangle.stack")

                Divider()
                    .background(Color("AccentWarm").opacity(0.10))
                    .padding(.leading, 18)

                statRow(title: "Dates covered", value: "\(dataStore.representedDateCount)", systemImage: "calendar")

                Divider()
                    .background(Color("AccentWarm").opacity(0.10))
                    .padding(.leading, 18)

                statRow(title: "Reading tone", value: preferences.currentTonePreference.rawValue, systemImage: "dial.medium")
            }
            .background(elevatedSurface)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("About Today")

            VStack(spacing: 14) {
                Text("Today keeps reading preferences and card reactions on this device. The historical collection is bundled with the app, filtered for publishable records, and refreshed through app updates.")
                    .font(.system(size: metrics.cardSummarySize, weight: .regular, design: .serif))
                    .foregroundStyle(Color("TextSecondary"))
                    .lineSpacing(metrics.cardSummaryLineSpacing - 1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.18))
                    .frame(height: 0.5)

                Text("Made with care · v1.0")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Color("TextTertiary"))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(18)
            .background(elevatedSurface)
        }
    }

    private var elevatedSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color("CardBackground"))

            RoundedRectangle(cornerRadius: 20, style: .continuous)
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
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color("AccentWarm").opacity(0.18), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
        .shadow(color: Color("AccentWarm").opacity(0.10), radius: 16, x: 0, y: 8)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(Color("TextTertiary"))
            .padding(.leading, 4)
    }

    private var footerText: String {
        switch preferences.currentTonePreference {
        case .uplifting:
            return "Find the wonder, resilience, and human spark."
        case .balanced:
            return "Keep the record thoughtful, clear, and even-handed."
        case .unflinching:
            return "Lean into the conflict, consequence, and harder truths."
        }
    }

    private var densityFooterText: String {
        switch preferences.currentReadingDensity {
        case .compact:
            return "Tighter type and trim margins for more cards on each screen."
        case .standard:
            return "The original editorial baseline, with calm spacing and a familiar measure."
        case .comfortable:
            return "A little more breathing room and slightly larger reading type."
        }
    }

    private func statRow(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("AccentWarm"))
                .frame(width: 22)

            Text(title)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(Color("TextSecondary"))

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color("TextPrimary"))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

#Preview {
    PreferencesView()
        .environmentObject(UserPreferences())
        .environmentObject(DataStore())
}
