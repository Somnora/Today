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
    ///
    /// Wikimedia serves only a fixed set of thumbnail widths and answers any
    /// other width with HTTP 400, so widths the corpus has used that are no
    /// longer served are mapped onto a width that is.
    var imageURL: URL? {
        guard let imageURLString else { return nil }
        return URL(string: Self.servedWikimediaThumbnailURLString(imageURLString))
    }

    /// Thumbnail widths Wikimedia stopped serving (verified 2026-11-09), and
    /// the served width they are rewritten to. See https://w.wiki/GHai.
    static let retiredWikimediaThumbnailWidths = ["480", "640", "800", "1024"]
    static let servedWikimediaThumbnailWidth = "960"

    static func servedWikimediaThumbnailURLString(_ urlString: String) -> String {
        guard urlString.contains("upload.wikimedia.org/"), urlString.contains("/thumb/") else {
            return urlString
        }
        for width in retiredWikimediaThumbnailWidths {
            let marker = "/\(width)px-"
            if urlString.contains(marker) {
                return urlString.replacingOccurrences(of: marker, with: "/\(servedWikimediaThumbnailWidth)px-")
            }
        }
        return urlString
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

// MARK: - Reader-facing entry copy

/// The text blocks the detail screen shows for an event after repeated
/// paragraphs, generic filler notes and editorial process notes are removed.
///
/// The corpus was assembled by several pipelines, so many records repeat the
/// same paragraph in more than one field or carry notes written for editors
/// rather than readers. This is a display-time guard; the data stays as is.
struct EntryCopy: Equatable {
    /// Opening paragraph. Usually the card summary; when the summary is a
    /// clipped opening of the body it is the body's full first sentence.
    let lead: String
    /// Main narrative, or nil when it would only repeat the lead.
    let body: String?
    /// Editorial note, or nil when it is generic, repeated or internal.
    let whyItMatters: String?
    /// Further background, or nil when it would only repeat the body.
    let deeperStory: String?
}

extension HistoricalEvent {
    /// - Parameter genericNotes: comparison keys of "why it matters" notes
    ///   shared by several records (see `genericNotes(in:)`).
    func entryCopy(genericNotes: Set<String> = []) -> EntryCopy {
        let originalLead = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        var body = EntryText.removingEditorialNotes(from: detail)
        var deeper = deepDive.flatMap(EntryText.removingEditorialNotes(from:))

        // Deeper story against the body.
        if let currentBody = body, let currentDeeper = deeper {
            let bodyKey = EntryText.key(currentBody)
            let deeperKey = EntryText.key(currentDeeper)
            if bodyKey.contains(deeperKey) {
                deeper = nil
            } else if deeperKey.hasPrefix(bodyKey) {
                if currentDeeper.hasPrefix(currentBody), EntryText.endsSentence(currentBody) {
                    deeper = EntryText.remainder(of: currentDeeper, after: currentBody, minimumLength: 40)
                } else {
                    // The body is a clipped copy of the deeper story.
                    body = currentDeeper
                    deeper = nil
                }
            }
        } else if body == nil, let currentDeeper = deeper {
            body = currentDeeper
            deeper = nil
        }

        // Body against the lead.
        var lead = originalLead
        if let currentBody = body {
            let leadKey = EntryText.key(originalLead)
            let bodyKey = EntryText.key(currentBody)
            if bodyKey == leadKey {
                body = nil
            } else if bodyKey.hasPrefix(leadKey) {
                if currentBody.hasPrefix(originalLead), EntryText.endsSentence(originalLead) {
                    // A leftover too short to stand alone is usually the tail
                    // of a sentence split at an abbreviation ("St. Nicholas").
                    let rest = EntryText.remainder(of: currentBody, after: originalLead, minimumLength: 12)
                    if rest == nil, currentBody.count > originalLead.count {
                        lead = currentBody
                    }
                    body = rest
                } else if let first = EntryText.sentences(in: currentBody).first,
                          first.count <= 420,
                          EntryText.key(first).hasPrefix(leadKey),
                          currentBody.hasPrefix(first) {
                    let rest = EntryText.remainder(of: currentBody, after: first, minimumLength: 12)
                    lead = rest == nil ? currentBody : first
                    body = rest
                }
            }
        }

        if let currentDeeper = deeper {
            let deeperKey = EntryText.key(currentDeeper)
            if deeperKey == EntryText.key(lead) || deeperKey == EntryText.key(originalLead) {
                deeper = nil
            }
        }

        var note = whyItMatters.flatMap(EntryText.removingEditorialNotes(from:))
        if let currentNote = note {
            let noteKey = EntryText.key(currentNote)
            let repeatsShownText = noteKey == EntryText.key(contextLine)
                || EntryText.key(lead).contains(noteKey)
                || (body.map { EntryText.key($0).contains(noteKey) } ?? false)
            if genericNotes.contains(noteKey) || repeatsShownText {
                note = nil
            }
        }

        // The note and the deeper story sometimes carry the same paragraph.
        if let currentNote = note, let currentDeeper = deeper {
            let noteKey = EntryText.key(currentNote)
            let deeperKey = EntryText.key(currentDeeper)
            if noteKey == deeperKey {
                deeper = nil
            } else if deeperKey.contains(noteKey) {
                note = nil
            } else if noteKey.contains(deeperKey) {
                deeper = nil
            }
        }

        return EntryCopy(lead: lead, body: body, whyItMatters: note, deeperStory: deeper)
    }

    /// Comparison keys of "why it matters" notes used by at least
    /// `minimumUses` records. A note shared that widely is category filler,
    /// not a comment on any one event.
    static func genericNotes(in events: [HistoricalEvent], minimumUses: Int = 3) -> Set<String> {
        var uses: [String: Int] = [:]
        for event in events {
            guard let note = event.whyItMatters else { continue }
            uses[EntryText.key(note), default: 0] += 1
        }
        return Set(uses.filter { $0.value >= minimumUses }.keys)
    }
}

enum EntryText {
    /// Case- and whitespace-insensitive comparison key, ignoring a trailing
    /// period or ellipsis.
    static func key(_ text: String) -> String {
        var collapsed = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased()
        while let last = collapsed.last, ".…".contains(last) || last.isWhitespace {
            collapsed.removeLast()
        }
        return collapsed
    }

    static func endsSentence(_ text: String) -> Bool {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = trimmed.last, "\"”’')]".contains(last) {
            trimmed.removeLast()
        }
        guard let last = trimmed.last else { return false }
        return ".!?".contains(last)
    }

    /// What follows `prefix` in `text`, or nil when too little is left to
    /// stand as its own paragraph. `text` must start with `prefix`.
    static func remainder(of text: String, after prefix: String, minimumLength: Int) -> String? {
        let rest = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return rest.count >= minimumLength ? rest : nil
    }

    static func sentences(in text: String) -> [String] {
        var result: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { substring, _, _, _ in
            if let sentence = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty {
                result.append(sentence)
            }
        }
        return result
    }

    /// Phrases that only occur in notes written for editors: source-review
    /// bookkeeping, descriptions of how a record was repaired, and remarks
    /// about the collection itself. Tuned against the bundled corpus to
    /// avoid ordinary prose ("presidential candidate", "the record crowd").
    private static let editorialNotePattern: NSRegularExpression? = {
        let phrases = [
            #"source-(confirmed|backed|supported|reviewed|verified)"#,
            #"\bthe record (now|uses|avoids|keeps|treats|stays|is (strongest|better framed|framed))\b"#,
            #"\bthe repair(ed)?\b"#,
            #"\brepaired (wording|record|copy|claim|entry|card)\b"#,
            #"\btoday in time\b"#,
            #"\b(the|this|our) corpus\b"#,
            #"\bthis candidate\b"#,
            #"\bcandidate reserve\b"#,
            #"\bprovenance\b"#,
            #"\bapp-facing\b"#,
            #"\b(the|this) (entry|wording|copy) (now|avoids|keeps|stays|uses)\b"#,
            #"\b(broadens|gives|helps|belongs in) the app\b"#,
            #"\bthis entry is drawn from\b"#,
            #"\bused for this card\b"#,
            #"\bthis card needs\b"#,
            #"\bfor today, the editorial\b"#,
            #"\bexact-date (source|cultural|record)"#,
            #"\bcalendar (date|day)s? that (is|are) otherwise\b"#,
            #"\bto a shallow calendar date\b"#,
            #"\bunsupported (claim|same-day|first)"#
        ]
        return try? NSRegularExpression(pattern: phrases.joined(separator: "|"), options: [.caseInsensitive])
    }()

    static func isEditorialNote(_ text: String) -> Bool {
        guard let pattern = editorialNotePattern else { return false }
        return pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// Drops sentences that are editorial process notes, paragraph by
    /// paragraph. Text without such sentences is returned unchanged; nil
    /// means nothing reader-facing was left.
    static func removingEditorialNotes(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard isEditorialNote(trimmed) else { return trimmed }

        let paragraphs = trimmed
            .components(separatedBy: .newlines)
            .compactMap { paragraph -> String? in
                guard isEditorialNote(paragraph) else {
                    let kept = paragraph.trimmingCharacters(in: .whitespaces)
                    return kept.isEmpty ? nil : kept
                }
                let kept = sentences(in: paragraph).filter { !isEditorialNote($0) }
                return kept.isEmpty ? nil : kept.joined(separator: " ")
            }
        return paragraphs.isEmpty ? nil : paragraphs.joined(separator: "\n\n")
    }
}
