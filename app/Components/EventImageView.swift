import SwiftUI

/// Remote lead image for an event.
///
/// Renders nothing when the event has no image, so the existing text-only
/// layout stays intact for the ~15% of records without artwork. While the
/// image loads it shows a soft, tone-aware placeholder; on failure it falls
/// back to that same placeholder rather than an empty gap.
struct EventHeroImage: View {
    let event: HistoricalEvent
    var height: CGFloat
    var corners: Corners = .topOnly

    enum Corners {
        case topOnly      // card banner: round the top edge only
        case all          // framed photo
        case none         // full-bleed
    }

    var body: some View {
        if let url = event.imageURL {
            AsyncImage(
                url: url,
                transaction: Transaction(animation: .easeOut(duration: 0.28))
            ) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity)
                case .empty:
                    placeholder.overlay(
                        ProgressView().tint(Color("AccentWarm").opacity(0.6))
                    )
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(clipShape)
            .overlay(
                clipShape.strokeBorder(Color("AccentWarm").opacity(0.14), lineWidth: 0.5)
            )
            .accessibilityHidden(true)
        }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [
                Color("AccentWarm").opacity(0.14),
                Color("AccentWarm").opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: event.category.icon)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Color("AccentWarm").opacity(0.30))
        )
    }

    private var clipShape: AnyInsettableShape {
        switch corners {
        case .topOnly:
            return AnyInsettableShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24,
                    style: .continuous
                )
            )
        case .all:
            return AnyInsettableShape(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
        case .none:
            return AnyInsettableShape(Rectangle())
        }
    }
}

/// Small, tappable image-credit caption for the detail view.
struct EventImageCredit: View {
    let event: HistoricalEvent

    var body: some View {
        if let attribution = event.imageAttribution {
            let label = Label(attribution, systemImage: "photo")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color("TextTertiary"))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Group {
                if let credit = event.imageCreditURL {
                    Link(destination: credit) { label }
                } else {
                    label
                }
            }
            .accessibilityLabel("Image credit: \(attribution)")
        }
    }
}

/// Type-erased insettable shape so `clipShape`/`strokeBorder` can share one value.
struct AnyInsettableShape: InsettableShape {
    private let pathBuilder: (CGRect) -> Path
    private let insetBuilder: (CGFloat) -> AnyInsettableShape

    init<S: InsettableShape>(_ shape: S) {
        pathBuilder = { shape.path(in: $0) }
        insetBuilder = { AnyInsettableShape(shape.inset(by: $0)) }
    }

    func path(in rect: CGRect) -> Path { pathBuilder(rect) }
    func inset(by amount: CGFloat) -> AnyInsettableShape { insetBuilder(amount) }
}
