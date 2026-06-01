import WidgetKit
import SwiftUI
import AppIntents

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
}

struct TodayWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TodayWidgetEntry {
        TodayWidgetEntry(date: Date(), event: placeholderEvent, density: .standard)
    }

    func snapshot(for configuration: TodayWidgetConfigurationIntent, in context: Context) async -> TodayWidgetEntry {
        TodayWidgetEntry(date: Date(), event: placeholderEvent, density: configuration.density)
    }

    func timeline(for configuration: TodayWidgetConfigurationIntent, in context: Context) async -> Timeline<TodayWidgetEntry> {
        let entry = TodayWidgetEntry(date: Date(), event: placeholderEvent, density: configuration.density)
        let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
        return Timeline(entries: [entry], policy: .after(tomorrow))
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

    var body: some View {
        Group {
            if let event = entry.event {
                content(for: event)
            } else {
                emptyStateView
            }
        }
        .widgetURL(URL(string: "today://today"))
    }

    @ViewBuilder
    private func content(for event: HistoricalEvent) -> some View {
        switch widgetFamily {
        case .systemSmall:
            smallWidgetView(event: event)
        default:
            mediumWidgetView(event: event)
        }
    }

    private func smallWidgetView(event: HistoricalEvent) -> some View {
        VStack(alignment: .leading, spacing: widgetMetrics.smallStackSpacing) {
            HStack(spacing: 6) {
                Text(event.yearLabel)
                    .font(.system(size: widgetMetrics.smallMetaSize, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)

                Rectangle()
                    .fill(.secondary.opacity(0.5))
                    .frame(height: 0.6)
            }

            Spacer(minLength: 0)

            Text(event.title)
                .font(.system(size: widgetMetrics.smallTitleSize, weight: .semibold, design: .serif))
                .foregroundStyle(.primary)
                .lineLimit(widgetMetrics.smallTitleLineLimit)
                .lineSpacing(widgetMetrics.smallTitleLineSpacing)

            Text(event.category.displayName.uppercased())
                .font(.system(size: widgetMetrics.smallMetaSize - 1, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)

                Spacer()

                Text(event.yearLabel)
                    .font(.system(size: widgetMetrics.mediumMetaSize, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
            }

            Text(event.title)
                .font(.system(size: widgetMetrics.mediumTitleSize, weight: .semibold, design: .serif))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(event.summary)
                .font(.system(size: widgetMetrics.mediumSummarySize, weight: .regular, design: .serif))
                .foregroundStyle(.secondary)
                .lineLimit(widgetMetrics.mediumSummaryLineLimit)
                .lineSpacing(widgetMetrics.mediumSummaryLineSpacing)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Rectangle()
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 14, height: 0.6)

                Text(event.monthDayString.uppercased())
                    .font(.system(size: widgetMetrics.mediumDateSize - 1, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
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
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today Card")
        .description("A quietly kept historical note for the day.")
        .supportedFamilies([.systemSmall, .systemMedium])
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
