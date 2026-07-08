import Foundation

struct HistoricalEvent: Identifiable, Codable, Hashable {
    let id: String
    let month: Int
    let day: Int
    let year: Int?
    let title: String
    let summary: String
    let contextLine: String
    let detail: String
    let category: EventCategory
    let tone: EventTone
    let source: String
    let sources: [String]
    let tags: [String]
    let deepDive: String?
    let whyItMatters: String?
    let provenance: String?
    let editorialStatus: String?
    let imageURLString: String?
    let imageAttribution: String?
    let imageCreditURLString: String?

    init(
        id: String,
        month: Int,
        day: Int,
        year: Int?,
        title: String,
        summary: String,
        contextLine: String,
        detail: String,
        category: EventCategory,
        tone: EventTone,
        source: String,
        sources: [String] = [],
        tags: [String] = [],
        deepDive: String? = nil,
        whyItMatters: String? = nil,
        provenance: String? = nil,
        editorialStatus: String? = nil,
        imageURLString: String? = nil,
        imageAttribution: String? = nil,
        imageCreditURLString: String? = nil
    ) {
        self.id = id
        self.month = month
        self.day = day
        self.year = year
        self.title = title
        self.summary = summary
        self.contextLine = contextLine
        self.detail = detail
        self.category = category
        self.tone = tone
        self.source = source
        self.sources = sources.isEmpty ? [source].filter { !$0.isEmpty } : sources
        self.tags = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.deepDive = deepDive?.nilIfBlank
        self.whyItMatters = whyItMatters?.nilIfBlank
        self.provenance = provenance?.nilIfBlank
        self.editorialStatus = editorialStatus?.nilIfBlank
        self.imageURLString = imageURLString?.nilIfBlank
        self.imageAttribution = imageAttribution?.nilIfBlank
        self.imageCreditURLString = imageCreditURLString?.nilIfBlank
    }

    /// Remote lead image for the event, when one is available.
    var imageURL: URL? {
        guard let imageURLString, let url = URL(string: imageURLString) else { return nil }
        return url
    }

    /// Link to the source page the image came from (for attribution tap-through).
    var imageCreditURL: URL? {
        guard let imageCreditURLString, let url = URL(string: imageCreditURLString) else { return nil }
        return url
    }

    var dateString: String {
        if let year {
            return "\(boundedMonthName) \(day), \(year)"
        }
        return "\(boundedMonthName) \(day)"
    }

    var monthDayString: String {
        "\(boundedMonthName) \(day)"
    }

    private var boundedMonthName: String {
        let monthSymbols = Calendar.current.monthSymbols
        guard !monthSymbols.isEmpty else { return "Month" }
        let index = min(max(month - 1, 0), monthSymbols.count - 1)
        return monthSymbols[index]
    }

    var yearLabel: String {
        year.map(String.init) ?? "Undated"
    }

    var shareText: String {
        let sourceText = sources.isEmpty ? source : sources.joined(separator: "\n")
        return "\(title) (\(dateString))\n\n\(summary)\n\n\(contextLine)\n\nSource: \(sourceText)"
    }

    func matches(month: Int, day: Int) -> Bool {
        self.month == month && self.day == day
    }

    var isPublishable: Bool {
        guard let editorialStatus else { return true }
        return !["duplicate", "weak_event", "defer"].contains(editorialStatus.normalizedStatusValue)
    }

    var displayTags: [String] {
        let categoryAliases: Set<String> = [
            category.rawValue.normalizedTagValue,
            category.displayName.normalizedTagValue
        ]

        var seen = Set<String>()
        return tags
            .filter { tag in
                tag.isUserFacingTag && !categoryAliases.contains(tag.normalizedTagValue)
            }
            .compactMap(\.polishedTagDisplayName)
            .filter { seen.insert($0).inserted }
            .prefix(4)
            .map { $0 }
    }

    var primaryDisplayTag: String? {
        displayTags.first
    }

    enum CodingKeys: String, CodingKey {
        case id
        case month
        case day
        case year
        case title
        case oneLiner = "one_liner"
        case summary
        case shortSummary = "short_summary"
        case description
        case contextLine
        case detail
        case deepDive = "deep_dive"
        case whyItMatters = "why_it_matters"
        case category
        case tags
        case tone
        case source
        case sources
        case provenance
        case editorialStatus = "editorial_status"
        case imageURLString = "image_url"
        case imageAttribution = "image_attribution"
        case imageCreditURLString = "image_credit_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeTrimmedString(forKey: .id)
        let month = try container.decode(Int.self, forKey: .month)
        let day = try container.decode(Int.self, forKey: .day)
        let year = try container.decodeIfPresent(Int.self, forKey: .year)
        let title = try container.decodeTrimmedString(forKey: .title)
        let oneLiner = try container.decodeTrimmedStringIfPresent(forKey: .oneLiner)
        let description = try container.decodeTrimmedStringIfPresent(forKey: .description)
        let shortSummary = try container.decodeTrimmedStringIfPresent(forKey: .shortSummary)
        let rawSummary = try container.decodeTrimmedStringIfPresent(forKey: .summary)
        let summary = oneLiner
            ?? description
            ?? shortSummary
            ?? rawSummary
            ?? ""
        let category = try container.decode(EventCategory.self, forKey: .category)
        let tone = try container.decodeIfPresent(EventTone.self, forKey: .tone) ?? .balanced
        let contextLine = try container.decodeTrimmedStringIfPresent(forKey: .contextLine)
            ?? EventCategory.contextLine(for: category, tone: tone)
        let detail = try container.decodeTrimmedStringIfPresent(forKey: .detail)
            ?? rawSummary
            ?? description
            ?? summary
        let deepDive = try container.decodeTrimmedStringIfPresent(forKey: .deepDive)
        let whyItMatters = try container.decodeTrimmedStringIfPresent(forKey: .whyItMatters)
        let decodedSources = try container.decodeStringArrayIfPresent(forKey: .sources) ?? []
        let source = try container.decodeTrimmedStringIfPresent(forKey: .source)
            ?? decodedSources.first
            ?? "Unattributed"
        let tags = try container.decodeStringArrayIfPresent(forKey: .tags) ?? []
        let provenance = try container.decodeTrimmedStringIfPresent(forKey: .provenance)
        let editorialStatus = try container.decodeTrimmedStringIfPresent(forKey: .editorialStatus)
        let imageURLString = try container.decodeTrimmedStringIfPresent(forKey: .imageURLString)
        let imageAttribution = try container.decodeTrimmedStringIfPresent(forKey: .imageAttribution)
        let imageCreditURLString = try container.decodeTrimmedStringIfPresent(forKey: .imageCreditURLString)

        guard (1...12).contains(month), (1...31).contains(day), !title.isEmpty, !summary.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Event requires valid month/day, title, and description.")
            )
        }

        self.init(
            id: id,
            month: month,
            day: day,
            year: year,
            title: title,
            summary: summary,
            contextLine: contextLine,
            detail: detail,
            category: category,
            tone: tone,
            source: source,
            sources: decodedSources,
            tags: tags,
            deepDive: deepDive,
            whyItMatters: whyItMatters,
            provenance: provenance,
            editorialStatus: editorialStatus,
            imageURLString: imageURLString,
            imageAttribution: imageAttribution,
            imageCreditURLString: imageCreditURLString
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(month, forKey: .month)
        try container.encode(day, forKey: .day)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encode(title, forKey: .title)
        try container.encode(summary, forKey: .summary)
        try container.encode(contextLine, forKey: .contextLine)
        try container.encode(detail, forKey: .detail)
        try container.encodeIfPresent(deepDive, forKey: .deepDive)
        try container.encodeIfPresent(whyItMatters, forKey: .whyItMatters)
        try container.encode(category, forKey: .category)
        try container.encode(tags, forKey: .tags)
        try container.encode(tone, forKey: .tone)
        try container.encode(source, forKey: .source)
        try container.encode(sources, forKey: .sources)
        try container.encodeIfPresent(provenance, forKey: .provenance)
        try container.encodeIfPresent(editorialStatus, forKey: .editorialStatus)
        try container.encodeIfPresent(imageURLString, forKey: .imageURLString)
        try container.encodeIfPresent(imageAttribution, forKey: .imageAttribution)
        try container.encodeIfPresent(imageCreditURLString, forKey: .imageCreditURLString)
    }
}

struct EventsData: Codable {
    let events: [HistoricalEvent]
    let robBundles: [RobBundleEnvelope]?

    enum CodingKeys: String, CodingKey {
        case events
        case robBundles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedEvents = try container.decodeIfPresent([FailableDecodable<HistoricalEvent>].self, forKey: .events) ?? []
        events = decodedEvents.compactMap(\.value).filter(\.isPublishable)
        robBundles = try container.decodeIfPresent([RobBundleEnvelope].self, forKey: .robBundles)
    }
}

struct RobBundleEnvelope: Codable {
    let schemaVersion: String
    let date: String
    let tag: String?
    let publishableUplifting: [RobBundleRecord]
    let publishableBalanced: [RobBundleRecord]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case date
        case tag
        case publishableUplifting = "publishable_uplifting"
        case publishableBalanced = "publishable_balanced"
    }
}

struct RobBundleRecord: Codable {
    let id: String
    let displayDate: String
    let year: Int?
    let title: String
    let summaryShort: String
    let summaryMedium: String
    let themes: [String]
    let tone: String
    let sources: RobBundleSources?

    enum CodingKeys: String, CodingKey {
        case id
        case displayDate = "display_date"
        case year
        case title
        case summaryShort = "summary_short"
        case summaryMedium = "summary_medium"
        case themes
        case tone
        case sources
    }
}

struct RobBundleSources: Codable {
    let wikimediaFeed: String?
    let locSearch: String?
    let pageRefs: [String]?

    enum CodingKeys: String, CodingKey {
        case wikimediaFeed = "wikimedia_feed"
        case locSearch = "loc_search"
        case pageRefs = "page_refs"
    }
}

extension HistoricalEvent {
    init?(bundleRecord: RobBundleRecord) {
        let parts = bundleRecord.displayDate.split(separator: "-")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let day = Int(parts[1]) else {
            return nil
        }

        let category = EventCategory(primaryTheme: bundleRecord.themes)
        let tone = EventTone(bundleTone: bundleRecord.tone)
        let source = bundleRecord.sources?.providerLabel ?? "Today editorial collection"

        self.init(
            id: bundleRecord.id,
            month: month,
            day: day,
            year: bundleRecord.year,
            title: bundleRecord.title.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: bundleRecord.summaryShort.trimmingCharacters(in: .whitespacesAndNewlines),
            contextLine: EventCategory.contextLine(for: category, tone: tone),
            detail: bundleRecord.summaryMedium.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            tone: tone,
            source: source,
            sources: bundleRecord.sources?.allReferences ?? []
        )
    }
}

enum EventCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case history
    case science
    case culture
    case arts
    case world
    case politics
    case nature
    case technology
    case exploration
    case sports
    case birth
    case death
    case strange

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = EventCategory(rawValue: rawValue.normalizedCategoryValue) ?? .history
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    init(primaryTheme themes: [String]) {
        let normalized = themes.map(\.normalizedCategoryValue)

        if normalized.contains(where: { ["science", "discovery", "space"].contains($0) }) {
            self = .science
        } else if normalized.contains(where: { ["innovation", "technology", "invention", "engineering"].contains($0) }) {
            self = .technology
        } else if normalized.contains(where: { ["arts", "art"].contains($0) }) {
            self = .arts
        } else if normalized.contains(where: { ["culture", "oddities", "curiosities", "humanity", "civil-rights", "civil_rights"].contains($0) }) {
            self = .culture
        } else if normalized.contains(where: { ["sports", "sport", "athletics"].contains($0) }) {
            self = .sports
        } else if normalized.contains(where: { ["birth", "births", "born"].contains($0) }) {
            self = .birth
        } else if normalized.contains(where: { ["death", "deaths", "died"].contains($0) }) {
            self = .death
        } else if normalized.contains(where: { ["strange", "interesting", "odd", "oddity", "curiosity"].contains($0) }) {
            self = .strange
        } else if normalized.contains(where: { ["exploration", "adventure"].contains($0) }) {
            self = .exploration
        } else if normalized.contains(where: { ["world", "international", "global", "statehood", "independence"].contains($0) }) {
            self = .world
        } else if normalized.contains(where: { ["nature", "environment"].contains($0) }) {
            self = .nature
        } else if normalized.contains(where: { ["politics", "government", "diplomacy"].contains($0) }) {
            self = .politics
        } else {
            self = .history
        }
    }

    var displayName: String {
        switch self {
        case .history: return "History"
        case .science: return "Science"
        case .culture: return "Culture"
        case .arts: return "Arts"
        case .world: return "World"
        case .politics: return "Politics"
        case .nature: return "Nature"
        case .technology: return "Technology"
        case .exploration: return "Exploration"
        case .sports: return "Sports"
        case .birth: return "Born Today"
        case .death: return "Remembered"
        case .strange: return "Strange"
        }
    }

    var icon: String {
        switch self {
        case .history: return "books.vertical"
        case .science: return "atom"
        case .culture: return "theatermasks"
        case .arts: return "paintpalette"
        case .world: return "globe.europe.africa"
        case .politics: return "building.columns"
        case .nature: return "leaf"
        case .technology: return "gearshape.2"
        case .exploration: return "map"
        case .sports: return "sportscourt"
        case .birth: return "sparkles"
        case .death: return "hourglass"
        case .strange: return "questionmark.diamond"
        }
    }

    static func contextLine(for category: EventCategory, tone: EventTone) -> String {
        switch (category, tone) {
        case (.science, _):
            return "A dated note from the long human habit of making the world more understandable."
        case (.technology, _):
            return "A reminder that invention usually arrives as a chain of practical daring."
        case (.culture, .uplifting), (.arts, .uplifting):
            return "Culture tends to last when delight and memory keep finding each other."
        case (.culture, _), (.arts, _):
            return "The record gets warmer when public life leaves behind scenes people keep returning to."
        case (.world, _):
            return "A civic milestone can redraw the map while becoming part of daily public memory."
        case (.politics, _):
            return "Public life changes in moments that only look inevitable once they are already behind us."
        case (.exploration, _):
            return "Adventure usually begins as organized patience in an unfamiliar direction."
        case (.nature, _):
            return "Some historical notes matter because they teach people how to keep paying attention."
        case (.sports, _):
            return "Games become history when effort turns into a story people keep retelling."
        case (.birth, _):
            return "A life begins quietly before anyone knows how far its influence will travel."
        case (.death, _):
            return "Remembrance keeps a life in conversation with the present."
        case (.strange, _):
            return "The odd corners of the record are often where history feels most alive."
        case (.history, .somber):
            return "History also asks to be kept carefully where the cost was human and lasting."
        default:
            return "Even a small dated note can reopen the texture of an era."
        }
    }
}

enum EventTone: String, Codable {
    case uplifting
    case balanced
    case somber

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        switch rawValue.lowercased() {
        case "uplifting", "hopeful", "light":
            self = .uplifting
        case "somber", "hard", "difficult", "heavy":
            self = .somber
        default:
            self = .balanced
        }
    }

    init(bundleTone: String) {
        switch bundleTone.lowercased() {
        case "uplifting": self = .uplifting
        case "hard": self = .somber
        default: self = .balanced
        }
    }
}

private extension RobBundleSources {
    var providerLabel: String {
        var providers: [String] = []

        if let wikimediaFeed, !wikimediaFeed.isEmpty {
            providers.append("Wikimedia")
        }
        if let locSearch, !locSearch.isEmpty {
            providers.append("Library of Congress")
        }
        if providers.isEmpty, let pageRefs, !pageRefs.isEmpty {
            providers.append("Reference pages")
        }

        return providers.isEmpty ? "Today editorial collection" : providers.joined(separator: " + ")
    }

    var allReferences: [String] {
        var references = [String]()

        if let wikimediaFeed, !wikimediaFeed.isEmpty {
            references.append(wikimediaFeed)
        }
        if let locSearch, !locSearch.isEmpty {
            references.append(locSearch)
        }
        if let pageRefs {
            references.append(contentsOf: pageRefs.filter { !$0.isEmpty })
        }

        return references
    }
}

struct FailableDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

private extension KeyedDecodingContainer {
    func decodeTrimmedString(forKey key: Key) throws -> String {
        try decode(String.self, forKey: key).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func decodeTrimmedStringIfPresent(forKey key: Key) throws -> String? {
        try decodeIfPresent(String.self, forKey: key)?.nilIfBlank
    }

    func decodeStringArrayIfPresent(forKey key: Key) throws -> [String]? {
        if let strings = try? decodeIfPresent([String].self, forKey: key) {
            return strings.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }

        if let string = try decodeIfPresent(String.self, forKey: key)?.nilIfBlank {
            return [string]
        }

        return nil
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalizedStatusValue: String {
        lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    var normalizedTagValue: String {
        lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    var isUserFacingTag: Bool {
        let internalTags: Set<String> = [
            "defer",
            "duplicate",
            "editorial_status",
            "fixture",
            "internal",
            "mvp",
            "needs_source_check",
            "provenance",
            "ready",
            "rob",
            "sample",
            "source_check",
            "weak_event"
        ]

        let normalized = normalizedTagValue
        return !normalized.isEmpty
            && !internalTags.contains(normalized)
            && !normalized.hasPrefix("source_")
            && !normalized.hasPrefix("editorial_")
            && !normalized.hasPrefix("corpus_")
    }

    var polishedTagDisplayName: String? {
        let words = normalizedTagValue
            .split(separator: "_")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !words.isEmpty else { return nil }

        return words
            .map { word in
                switch word {
                case "ai": return "AI"
                case "gps": return "GPS"
                case "nasa": return "NASA"
                case "uk": return "UK"
                case "un": return "UN"
                case "us", "usa": return "US"
                default:
                    return word.prefix(1).uppercased() + String(word.dropFirst())
                }
            }
            .joined(separator: " ")
    }

    var normalizedCategoryValue: String {
        let normalized = lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "/", with: "")

        switch normalized {
        case "art", "arts", "artculture", "culturearts", "artsandculture", "artandculture":
            return "arts"
        case "births", "born":
            return "birth"
        case "deaths", "died":
            return "death"
        case "sport", "athletics":
            return "sports"
        case "interesting", "odd", "oddity", "oddities", "curiosity", "curiosities":
            return "strange"
        case "civilrights", "humanity":
            return "culture"
        default:
            return normalized
        }
    }
}
