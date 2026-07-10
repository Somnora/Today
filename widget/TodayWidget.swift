import WidgetKit
import SwiftUI
import AppIntents
import UIKit

enum TodayWidgetDensity: String, AppEnum {
    case standard
    case compact

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Reading Density"

    static var caseDisplayRepresentations: [TodayWidgetDensity: DisplayRepresentation] = [
        .standard: "Standard",
        .compact: "Compact"
    ]
}

struct TodayWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Today Card"
    static var description = IntentDescription("Choose how tightly the widget reads.")

    @Parameter(title: "Density", default: .standard)
    var density: TodayWidgetDensity
}

struct TodayWidgetEntry: TimelineEntry {
    let date: Date
    let event: HistoricalEvent?
    let density: TodayWidgetDensity
    var imageData: Data? = nil
}

struct TodayWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TodayWidgetEntry {
        TodayWidgetEntry(date: Date(), event: placeholderEvent, density: .standard)
    }

    func snapshot(for configuration: TodayWidgetConfigurationIntent, in context: Context) async -> TodayWidgetEntry {
        if context.isPreview {
            return TodayWidgetEntry(date: Date(), event: placeholderEvent, density: configuration.density)
        }
        let event = await loadWidgetEvent()
        return TodayWidgetEntry(date: Date(), event: event, density: configuration.density, imageData: await loadImageData(for: event))
    }

    /// Emits entries for today plus the next two days so the card still rolls
    /// over at midnight when WidgetKit defers the requested reload.
    func timeline(for configuration: TodayWidgetConfigurationIntent, in context: Context) async -> Timeline<TodayWidgetEntry> {
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let result = await DataLoader.loadEvents(resourceCandidates: ["widget-events", "events"])

        var entries: [TodayWidgetEntry] = []
        for offset in 0..<3 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            let components = calendar.dateComponents([.month, .day], from: day)
            guard let month = components.month, let dayOfMonth = components.day,
                  let event = DataLoader.displayEvent(month: month, day: dayOfMonth, from: result.events) else {
                continue
            }
            entries.append(TodayWidgetEntry(
                date: offset == 0 ? now : day,
                event: event,
                density: configuration.density,
                imageData: await loadImageData(for: event)
            ))
        }

        if entries.isEmpty {
            entries = [TodayWidgetEntry(date: now, event: nil, density: configuration.density)]
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(24 * 60 * 60)
        return Timeline(entries: entries, policy: .after(tomorrow))
    }

    /// WidgetKit cannot use AsyncImage, so the lead image is fetched here and
    /// carried in the entry. Kept small and best-effort: any failure just falls
    /// back to the text-only card.
    private func loadImageData(for event: HistoricalEvent?) async -> Data? {
        guard let url = event?.imageURL else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("TodayAlmanac/1.0 (info@somnora.app)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  data.count < 2_500_000, UIImage(data: data) != nil else { return nil }
            return data
        } catch {
            return nil
        }
    }

    private func loadWidgetEvent(date: Date = Date()) async -> HistoricalEvent? {
        let result = await DataLoader.loadEvents(resourceCandidates: ["widget-events", "events"])
        let components = Calendar.current.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else {
            return result.events.first
        }

        return DataLoader.displayEvent(month: month, day: day, from: result.events)
    }

    private var placeholderEvent: HistoricalEvent {
        HistoricalEvent(
            id: "widget-placeholder",
            month: Calendar.current.component(.month, from: Date()),
            day: Calendar.current.component(.day, from: Date()),
            year: 1913,
            title: "A mountain observatory opens its doors",
            summary: "A new observatory gave the public a closer way to see the sky, turning curiosity into a nightly ritual.",
            contextLine: "Scientific wonder often begins with a room, a lens, and enough patience to look up.",
            detail: "When the observatory opened, it gave students and nearby residents a shared place to encounter astronomy firsthand.",
            category: .science,
            tone: .uplifting,
            source: "Today"
        )
    }
}

private struct WidgetMetrics {
    let density: TodayWidgetDensity

    var smallPadding: CGFloat { density == .compact ? 12 : 16 }
    var smallStackSpacing: CGFloat { density == .compact ? 6 : 9 }
    var smallTitleSize: CGFloat { density == .compact ? 14 : 15 }
    var smallTitleLineLimit: Int { density == .compact ? 4 : 3 }
    var smallTitleLineSpacing: CGFloat { density == .compact ? 1.5 : 2 }
    var smallMetaSize: CGFloat { 11 }

    var mediumPadding: CGFloat { density == .compact ? 14 : 18 }
    var mediumStackSpacing: CGFloat { density == .compact ? 8 : 11 }
    var mediumTitleSize: CGFloat { density == .compact ? 16.5 : 18 }
    var mediumSummarySize: CGFloat { density == .compact ? 11 : 12 }
    var mediumSummaryLineLimit: Int { density == .compact ? 4 : 3 }
    var mediumSummaryLineSpacing: CGFloat { density == .compact ? 1.5 : 2 }
    var mediumMetaSize: CGFloat { density == .compact ? 11 : 12 }
    var mediumDateSize: CGFloat { 11 }
}

struct TodayWidgetEntryView: View {
    var entry: TodayWidgetProvider.Entry
    @Environment(\.widgetFamily) private var widgetFamily

    private var widgetMetrics: WidgetMetrics {
        WidgetMetrics(density: entry.density)
    }

    private var uiImage: UIImage? {
        guard let data = entry.imageData else { return nil }
        return UIImage(data: data)
    }

    /// Photo backgrounds only apply to the home-screen families; lock-screen
    /// accessories stay monochrome.
    private var showsImageBackground: Bool {
        uiImage != nil && (widgetFamily == .systemSmall || widgetFamily == .systemMedium)
    }

    private var primaryText: Color { showsImageBackground ? .white : .primary }
    private var secondaryText: Color { showsImageBackground ? Color.white.opacity(0.82) : .secondary }

    var body: some View {
        Group {
            if let event = entry.event {
                content(for: event)
                    .shadow(color: showsImageBackground ? .black.opacity(0.45) : .clear, radius: 3, x: 0, y: 1)
            } else {
                emptyStateView
            }
        }
        .widgetURL(URL(string: "today://today"))
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    @ViewBuilder
    private var widgetBackground: some View {
        if let image = uiImage, showsImageBackground {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                LinearGradient(
                    colors: [.black.opacity(0.20), .black.opacity(0.32), .black.opacity(0.74)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        } else {
            Rectangle().fill(.fill.tertiary)
        }
    }

    @ViewBuilder
    private func content(for event: HistoricalEvent) -> some View {
        switch widgetFamily {
        case .systemSmall:
            smallWidgetView(event: event)
        case .accessoryInline:
            inlineAccessoryView(event: event)
        case .accessoryRectangular:
            rectangularAccessoryView(event: event)
        default:
            mediumWidgetView(event: event)
        }
    }

    private func inlineAccessoryView(event: HistoricalEvent) -> some View {
        Text("\(event.yearLabel) · \(event.title)")
    }

    private func rectangularAccessoryView(event: HistoricalEvent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(event.yearLabel)
                    .font(.system(size: 13, weight: .semibold, design: .serif))

                Text(event.monthDayString.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }

            Text(event.title)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func smallWidgetView(event: HistoricalEvent) -> some View {
        VStack(alignment: .leading, spacing: widgetMetrics.smallStackSpacing) {
            HStack(spacing: 6) {
                Text(event.yearLabel)
                    .font(.system(size: widgetMetrics.smallMetaSize, weight: .semibold, design: .serif))
                    .foregroundStyle(primaryText)

                Rectangle()
                    .fill(secondaryText.opacity(0.5))
                    .frame(height: 0.6)
            }

            Spacer(minLength: 0)

            Text(event.title)
                .font(.system(size: widgetMetrics.smallTitleSize, weight: .semibold, design: .serif))
                .foregroundStyle(primaryText)
                .lineLimit(widgetMetrics.smallTitleLineLimit)
                .lineSpacing(widgetMetrics.smallTitleLineSpacing)
                .minimumScaleFactor(0.82)

            Text(event.category.displayName.uppercased())
                .font(.system(size: widgetMetrics.smallMetaSize - 1, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(widgetMetrics.smallPadding)
    }

    private func mediumWidgetView(event: HistoricalEvent) -> some View {
        VStack(alignment: .leading, spacing: widgetMetrics.mediumStackSpacing) {
            HStack(spacing: 6) {
                Label(event.category.displayName.uppercased(), systemImage: event.category.icon)
                    .font(.system(size: widgetMetrics.mediumMetaSize - 1, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(secondaryText)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer()

                Text(event.yearLabel)
                    .font(.system(size: widgetMetrics.mediumMetaSize, weight: .semibold, design: .serif))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Text(event.title)
                .font(.system(size: widgetMetrics.mediumTitleSize, weight: .semibold, design: .serif))
                .foregroundStyle(primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.86)

            Text(event.summary)
                .font(.system(size: widgetMetrics.mediumSummarySize, weight: .regular, design: .serif))
                .foregroundStyle(secondaryText)
                .lineLimit(widgetMetrics.mediumSummaryLineLimit)
                .lineSpacing(widgetMetrics.mediumSummaryLineSpacing)
                .minimumScaleFactor(0.90)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Rectangle()
                    .fill(secondaryText.opacity(0.5))
                    .frame(width: 14, height: 0.6)

                Text(event.monthDayString.uppercased())
                    .font(.system(size: widgetMetrics.mediumDateSize - 1, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(widgetMetrics.mediumPadding)
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 24))
            Text("Today")
                .font(.system(size: 15, weight: .semibold, design: .serif))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

@main
struct TodayWidget: Widget {
    let kind: String = "TodayWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TodayWidgetConfigurationIntent.self,
            provider: TodayWidgetProvider()
        ) { entry in
            TodayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today Card")
        .description("A quietly kept historical note for the day.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular])
    }
}

#Preview(as: .systemMedium) {
    TodayWidget()
} timeline: {
    TodayWidgetEntry(
        date: Date(),
        event: HistoricalEvent(
            id: "preview",
            month: 4,
            day: 19,
            year: 1913,
            title: "A mountain observatory opens its doors",
            summary: "A new observatory gave the public a closer way to see the sky, turning curiosity into a nightly ritual.",
            contextLine: "Scientific wonder often begins with a room, a lens, and enough patience to look up.",
            detail: "When the observatory opened, it gave students and nearby residents a shared place to encounter astronomy firsthand.",
            category: .science,
            tone: .uplifting,
            source: "Today"
        ),
        density: .standard
    )
}
