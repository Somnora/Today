import SwiftUI
import UIKit

struct EventDetailView: View {
    let event: HistoricalEvent

    @EnvironmentObject var thumbsStore: ThumbsStore
    @EnvironmentObject var preferences: UserPreferences
    @EnvironmentObject var savedStore: SavedStore
    @State private var isProvenanceExpanded = false

    private var currentReaction: Reaction? {
        thumbsStore.reactionFor(eventID: event.id)
    }

    private var metrics: ReadingMetrics {
        ReadingMetrics(density: preferences.currentReadingDensity)
    }

    private var isSaved: Bool {
        savedStore.isSaved(event.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: metrics.detailRootSpacing) {
                headingBlock

                divider

                summaryBlock
                detailBlock
                whyItMattersBlock
                deepDiveBlock
                reactionBlock
                provenanceBlock
                colophon
            }
            .padding(.horizontal, 24)
            .padding(.top, metrics.detailTopPadding)
            .padding(.bottom, 40)
        }
        .background(detailBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    toggleSaved()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isSaved ? "Remove bookmark" : "Bookmark")

                ShareLink(item: event.shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
        }
    }

    private var detailBackground: some View {
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

    private var divider: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color("AccentWarm").opacity(0.55))
                .frame(width: 4, height: 4)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color("AccentWarm").opacity(0.30),
                            Color("AccentWarm").opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
    }

    private var headingBlock: some View {
        VStack(alignment: .leading, spacing: metrics.detailHeadingSpacing) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.45))
                    .frame(width: 18, height: 0.8)

                Text("ALMANAC ENTRY")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(2.0)
                    .foregroundStyle(Color("AccentWarm"))

                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.18))
                    .frame(height: 0.6)
            }

            yearHeadingRow

            Text(event.title)
                .font(.system(size: metrics.detailTitleSize, weight: .semibold, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
                .kerning(-0.3)
                .lineSpacing(5)

            FlowLayout(spacing: 8, lineSpacing: 8) {
                Label(event.category.displayName, systemImage: event.category.icon)
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color("AccentWarm"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color("AccentWarm").opacity(0.10), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color("AccentWarm").opacity(0.22), lineWidth: 0.5)
                    )

                ForEach(displayTags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color("TextSecondary"))
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Color("CardBackground"), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color("AccentWarm").opacity(0.14), lineWidth: 0.5)
                        )
                }
            }
        }
    }

    private var yearHeadingRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(event.yearLabel)
                .font(.system(size: metrics.detailYearSize, weight: .semibold, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
                .kerning(-0.8)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.monthDayString.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(Color("TextTertiary"))

                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.40))
                    .frame(width: 22, height: 0.8)
            }
            .padding(.bottom, 6)
        }
    }

    private var summaryBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(event.summary)
                .font(.system(size: metrics.detailLeadSize, weight: .regular, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
                .lineSpacing(metrics.detailLeadLineSpacing)

            Text(event.contextLine)
                .font(.system(size: metrics.detailContextSize, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color("TextSecondary"))
                .lineSpacing(metrics.detailContextLineSpacing)
                .padding(.leading, 18)
                .padding(.vertical, 14)
                .padding(.trailing, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color("AccentWarm").opacity(0.55),
                                    Color("AccentWarm").opacity(0.20)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3)
                }
        }
    }

    private var detailBlock: some View {
        Text(event.detail)
            .font(.system(size: metrics.detailBodySize, weight: .regular, design: .serif))
            .foregroundStyle(Color("TextPrimary"))
            .lineSpacing(metrics.detailBodyLineSpacing)
    }

    @ViewBuilder
    private var whyItMattersBlock: some View {
        if let whyItMatters = event.whyItMatters {
            editorialBlock(title: "Why It Matters", systemImage: "sparkle.magnifyingglass", text: whyItMatters)
        }
    }

    @ViewBuilder
    private var deepDiveBlock: some View {
        if let deepDive = event.deepDive {
            VStack(alignment: .leading, spacing: 12) {
                Label("Deeper Story", systemImage: "text.book.closed")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Color("AccentWarm"))

                Text(deepDive)
                    .font(.system(size: metrics.detailEditorialBodySize, weight: .regular, design: .serif))
                    .foregroundStyle(Color("TextPrimary"))
                    .lineSpacing(metrics.detailEditorialBodyLineSpacing)
            }
            .padding(metrics.detailEditorialPadding)
            .background(plainEditorialSurface)
            .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
            .shadow(color: Color("AccentWarm").opacity(0.10), radius: 16, x: 0, y: 8)
        }
    }

    private var plainEditorialSurface: some View {
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
                .strokeBorder(Color("AccentWarm").opacity(0.16), lineWidth: 0.6)
        )
    }

    private var reactionBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.45))
                    .frame(width: 14, height: 0.6)

                Text("KEEP OR PASS")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(Color("TextTertiary"))

                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                reactionButton(
                    title: "Appreciate",
                    systemImage: currentReaction == .thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsup",
                    active: currentReaction == .thumbsUp
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    thumbsStore.toggleThumbsUp(for: event.id)
                }

                reactionButton(
                    title: "Not for me",
                    systemImage: currentReaction == .thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                    active: currentReaction == .thumbsDown,
                    subdued: true
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    thumbsStore.toggleThumbsDown(for: event.id)
                }
            }
        }
    }

    private func reactionButton(title: String, systemImage: String, active: Bool, subdued: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(active ? (subdued ? Color("TextSecondary") : Color("AccentWarm")) : Color("TextSecondary"))
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(active ? (subdued ? Color.gray.opacity(0.10) : Color("AccentWarm").opacity(0.14)) : Color("CardBackground"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color("AccentWarm").opacity(active && !subdued ? 0.32 : 0.14), lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
            .shadow(color: Color("AccentWarm").opacity(active && !subdued ? 0.18 : 0.06), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private var provenanceBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "scroll")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color("AccentWarm"))

                Text("SOURCES")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(Color("AccentWarm"))

                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.20))
                    .frame(height: 0.6)
            }

            if let provenance = event.provenance {
                DisclosureGroup("Editorial note", isExpanded: $isProvenanceExpanded) {
                    Text(provenance)
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .foregroundStyle(Color("TextSecondary"))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .padding(.top, 8)
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color("TextSecondary"))
                .padding(.bottom, displaySources.isEmpty ? 0 : 4)
                .tint(Color("AccentWarm"))
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(displaySources, id: \.self) { source in
                    sourceRow(source)
                }
            }
        }
        .padding(metrics.detailEditorialPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(plainEditorialSurface)
        .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
        .shadow(color: Color("AccentWarm").opacity(0.10), radius: 16, x: 0, y: 8)
    }

    private var colophon: some View {
        VStack(spacing: 10) {
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

            Text("End of entry")
                .font(.system(size: 11, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color("TextTertiary"))
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
    }

    private var displaySources: [String] {
        event.sources.isEmpty ? [event.source] : event.sources
    }

    private var displayTags: [String] {
        event.displayTags
    }

    private func editorialBlock(title: String, systemImage: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Color("AccentWarm"))

            Text(text)
                .font(.system(size: metrics.detailEditorialBodySize, weight: .regular, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
                .lineSpacing(metrics.detailEditorialBodyLineSpacing - 1)
        }
        .padding(metrics.detailEditorialPadding)
        .background(editorialSurface)
    }

    private var editorialSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color("AccentWarm").opacity(0.12),
                            Color("AccentWarm").opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: 240
                    )
                )
                .blendMode(.plusLighter)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color("AccentWarm").opacity(0.22), lineWidth: 0.6)
        )
    }

    @ViewBuilder
    private func sourceRow(_ source: String) -> some View {
        if let url = URL(string: source), url.scheme?.hasPrefix("http") == true {
            Link(destination: url) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "link")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color("AccentWarm"))
                        .padding(.top, 3)

                    Text(sourceTitle(for: url))
                        .font(.system(size: 14.5, weight: .regular, design: .serif))
                        .foregroundStyle(Color("TextSecondary"))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color("AccentWarm").opacity(0.85))
                    .padding(.top, 3)

                Text(source)
                    .font(.system(size: 14.5, weight: .regular, design: .serif))
                    .foregroundStyle(Color("TextSecondary"))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private func sourceTitle(for url: URL) -> String {
        let host = url.host()?.replacingOccurrences(of: "www.", with: "") ?? "Source"
        let lastPath = url.lastPathComponent.removingPercentEncoding ?? ""

        if lastPath.isEmpty || lastPath == "all" {
            return host
        }

        return "\(host) / \(lastPath.replacingOccurrences(of: "_", with: " "))"
    }

    private func toggleSaved() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        savedStore.toggle(event.id)
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widestLine: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let shouldWrap = currentX > 0 && currentX + size.width > maxWidth

            if shouldWrap {
                widestLine = max(widestLine, currentX - spacing)
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }

            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        widestLine = max(widestLine, currentX > 0 ? currentX - spacing : 0)
        return CGSize(width: maxWidth > 0 ? maxWidth : widestLine, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let shouldWrap = currentX > bounds.minX && currentX + size.width > bounds.maxX

            if shouldWrap {
                currentX = bounds.minX
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )

            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        EventDetailView(
            event: HistoricalEvent(
                id: "preview-1",
                month: 4,
                day: 19,
                year: 1913,
                title: "A mountain observatory opens its doors",
                summary: "A new observatory gave the public a closer way to see the sky, turning curiosity into a nightly ritual.",
                contextLine: "Scientific wonder often begins with a room, a lens, and enough patience to look up.",
                detail: "When the observatory opened, it gave students, visitors, and nearby residents a shared place to encounter astronomy firsthand. Its importance was not only technical. It changed the emotional scale of the night sky, making distant things feel newly intimate.",
                category: .science,
                tone: .uplifting,
                source: "University observatory record"
            )
        )
        .environmentObject(ThumbsStore())
        .environmentObject(UserPreferences())
        .environmentObject(SavedStore())
    }
}
