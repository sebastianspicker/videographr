// MARK: - Research codebook catalogue (L6) - documentation only

/// Stable documentation of software code families (not official human codebooks).
public struct ResearchCodebookEntryValues: Sendable {
    public var id = ""
    public var family = ""
    public var code = ""
    public var titleDE = ""
    public var researchNoteDE = ""

    public init() {}
}

public enum ResearchCodebookCatalogue: Sendable {
    public struct Entry: Equatable, Sendable, Identifiable {
        public var id: String
        public var family: String
        public var code: String
        public var titleDE: String
        public var researchNoteDE: String

        public init(_ values: ResearchCodebookEntryValues) {
            id = values.id
            family = values.family
            code = values.code
            titleDE = values.titleDE
            researchNoteDE = values.researchNoteDE
        }
    }

    public static var ipnEntries: [Entry] {
        IPNDimensionCode.allCases.map { code in
            var values = ResearchCodebookEntryValues()
            values.id = "ipn-\(code.rawValue)"
            values.family = PedagogicalCodeFamily.ipnProcessQuality.rawValue
            values.code = code.rawValue
            values.titleDE = code.titleDE
            values.researchNoteDE = code.researchNoteDE
            return Entry(values)
        }
    }

    public static var timssEntries: [Entry] {
        TIMSSActivityCode.allCases.map { code in
            var values = ResearchCodebookEntryValues()
            values.id = "timss-\(code.rawValue)"
            values.family = PedagogicalCodeFamily.timssActivityScript.rawValue
            values.code = code.rawValue
            values.titleDE = code.titleDE
            values.researchNoteDE = "TIMSS Video teaching-script / activity structure proxy (Stigler/Hiebert lineage)."
            return Entry(values)
        }
    }

    public static var gtiEntries: [Entry] {
        GTIQualityCode.allCases.map { code in
            var values = ResearchCodebookEntryValues()
            values.id = "gti-\(code.rawValue)"
            values.family = PedagogicalCodeFamily.gtiQuality.rawValue
            values.code = code.rawValue
            values.titleDE = code.titleDE
            values.researchNoteDE = code.researchNoteDE
            return Entry(values)
        }
    }

    public static var allEntries: [Entry] {
        ipnEntries + timssEntries + gtiEntries
    }

    public static var familyCounts: [String: Int] {
        [
            "ipn": IPNDimensionCode.allCases.count,
            "timss": TIMSSActivityCode.allCases.count,
            "gti": GTIQualityCode.allCases.count
        ]
    }

    /// Boundary statement for exports / Learn / Info.
    public static let softwareBoundaryDE =
        "Software-Strukturproxies aus CV/Szene/Preset - keine multi-rater-validierten Human-Codes gegen offizielle Codebooks."

}

// MARK: - Unvalidated rule-set report (L9)
