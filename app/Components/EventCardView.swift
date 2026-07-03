import SwiftUI

struct EventCardView: View {
    let event: HistoricalEvent
    @EnvironmentObject var thumbsStore: ThumbsStore
    @EnvironmentObject var preferences: UserPreferences
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    private var currentReaction: Reaction? {
        thumbsStore.reactionFor(eventID: event.id)
    }

    private var metrics: ReadingMetrics {
        ReadingMetrics(density: preferences.currentReadingDensity, typeScale: typeScale)
    }

    private var toneAccent: Color {
        Color("AccentWarm")
    }

    private var toneWashOpacity: Double {
        switch event.tone {
        case .uplifting: return 0.10
        case .balanced: return 0.06
        case .somber: return 0.04
        }
    }

    private var cardAccessibilityLabel: String {
        "\(event.title), \(event.dateString), \(event.category.displayName). \(event.summary)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.cardStackSpacing) {
            headerRow
            yearBlock
            titleBlock
            contextBlock
            footerRow
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardSurface)
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.85),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 1.5, x: 0, y: 1)
        .shadow(color: toneAccent.opacity(0.16), radius: 22, x: 0, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint("Opens the full almanac entry")
    }

    private var cardSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("CardBackground"))

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            toneAccent.opacity(toneWashOpacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: 220
                    )
                )
                .blendMode(.plusLighter)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            toneAccent.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(toneAccent.opacity(0.20), lineWidth: 0.6)
        )
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 10) {
            categoryBadge

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(toneAccent.opacity(0.55))
                    .frame(width: 3.5, height: 3.5)

                Text(event.monthDayString.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Color("TextTertiary"))
            }
        }
    }

    private var categoryBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: event.category.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(toneAccent)

            Text(event.category.displayName.uppercased())
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(toneAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(toneAccent.opacity(0.10))
        )
        .overlay(
            Capsule()
                .stroke(toneAccent.opacity(0.22), lineWidth: 0.5)
        )
    }

    private var yearBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(event.yearLabel)
                .font(.system(size: metrics.cardYearSize, weight: .semibold, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
                .kerning(-0.4)

            yearOrnament
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    private var yearOrnament: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(toneAccent.opacity(0.35))
                .frame(height: 0.8)
                .frame(maxWidth: .infinity)

            Image(systemName: "diamond.fill")
                .font(.system(size: 4, weight: .regular))
                .foregroundStyle(toneAccent.opacity(0.60))

            Rectangle()
                .fill(toneAccent.opacity(0.35))
                .frame(width: 14, height: 0.8)
        }
        .offset(y: -8)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: metrics.cardTitleStackSpacing) {
            Text(event.title)
                .font(.system(size: metrics.cardTitleSize, weight: .semibold, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
                .kerning(-0.2)
                .multilineTextAlignment(.leading)

            Text(event.summary)
                .font(.system(size: metrics.cardSummarySize, weight: .regular, design: .serif))
                .foregroundStyle(Color("TextSecondary"))
                .lineSpacing(metrics.cardSummaryLineSpacing)
                .lineLimit(5)
        }
    }

    private var contextBlock: some View {
        Text(event.contextLine)
            .font(.system(size: metrics.cardContextSize, weight: .regular, design: .serif))
            .italic()
            .foregroundStyle(Color("TextSecondary"))
            .lineSpacing(metrics.cardContextLineSpacing)
            .padding(.leading, 16)
            .padding(.vertical, 10)
            .padding(.trailing, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                toneAccent.opacity(0.55),
                                toneAccent.opacity(0.20)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2.5)
            }
    }

    private var footerRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                footerLeadingContent

                Spacer()

                readEntryPill
            }

            VStack(alignment: .leading, spacing: 12) {
                footerLeadingContent
                readEntryPill
            }
        }
    }

    @ViewBuilder
    private var footerLeadingContent: some View {
        if let currentReaction {
            Label(
                currentReaction == .thumbsUp ? "Kept" : "Passed",
                systemImage: currentReaction == .thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsdown.fill"
            )
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(currentReaction == .thumbsUp ? toneAccent : Color("TextTertiary"))
        } else if let tag = event.primaryDisplayTag {
            Text(tag)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color("TextTertiary"))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var readEntryPill: some View {
        HStack(spacing: 6) {
            Text("Read entry")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(toneAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.88)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(toneAccent)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(toneAccent.opacity(0.10))
        )
        .overlay(
            Capsule()
                .stroke(toneAccent.opacity(0.22), lineWidth: 0.5)
        )
    }
}

#Preview {
    EventCardView(
        event: HistoricalEvent(
            id: "preview-1",
            month: 4,
            day: 19,
            year: 1911,
            title: "The first quiet room for recorded music",
            summary: "A city listening library opened its doors, letting ordinary people spend unhurried time with recorded sound.",
            contextLine: "A small civic room can change how culture is kept close.",
            detail: "In the early twentieth century, public listening rooms became an elegant bridge between archives and everyday life.",
            category: .culture,
            tone: .uplifting,
            source: "Municipal archive"
        )
    )
    .padding()
    .background(Color("BackgroundWarm"))
    .environmentObject(ThumbsStore())
    .environmentObject(UserPreferences())
}
