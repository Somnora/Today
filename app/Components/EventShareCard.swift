import SwiftUI
import UIKit

/// Fixed-width editorial card rendered offscreen for the share sheet — the
/// same paper-and-serif look as the in-app cards, sized for social feeds.
/// Text-only on purpose: remote imagery may not be loaded at render time.
struct EventShareCardView: View {
    let event: HistoricalEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            masthead

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(event.yearLabel)
                    .font(.system(size: 52, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("TextPrimary"))
                    .kerning(-1)

                Text(event.monthDayString.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(Color("TextTertiary"))
            }

            Text(event.title)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
                .kerning(-0.3)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text(event.summary)
                .font(.system(size: 14.5, weight: .regular, design: .serif))
                .foregroundStyle(Color("TextSecondary"))
                .lineSpacing(4)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)

            ornament

            HStack {
                Text(event.category.displayName.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(Color("AccentWarm"))

                Spacer()

                Text("Today in Time")
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color("TextTertiary"))
            }
        }
        .padding(30)
        .frame(width: 420, alignment: .leading)
        .background(
            ZStack {
                Color("BackgroundWarm")

                LinearGradient(
                    colors: [
                        Color("AccentWarm").opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        )
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

    private var ornament: some View {
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
}

@MainActor
enum ShareCardRenderer {
    /// Renders the share card at 3× for crisp export. Returns nil only if
    /// ImageRenderer fails, in which case callers fall back to text sharing.
    static func image(for event: HistoricalEvent) -> Image? {
        let renderer = ImageRenderer(content: EventShareCardView(event: event))
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}

#Preview {
    EventShareCardView(
        event: HistoricalEvent(
            id: "preview-1",
            month: 7,
            day: 20,
            year: 1969,
            title: "Apollo 11 lands on the Moon",
            summary: "Neil Armstrong and Buzz Aldrin land the lunar module Eagle in the Sea of Tranquility, and hundreds of millions listen in.",
            contextLine: "Exploration is a long chain of practical daring.",
            detail: "",
            category: .exploration,
            tone: .uplifting,
            source: "NASA"
        )
    )
}
