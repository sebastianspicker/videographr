import Foundation

/// Lesson Analysis Framework–style prompts (Santagata): goals, student learning, strategies, alternatives.
public enum ReflectionPromptID: String, Codable, CaseIterable, Sendable, Identifiable {
    case lessonGoals
    case studentLearningEvidence
    case instructionalStrategies
    case alternatives

    public var id: String { rawValue }

    public var titleDE: String {
        switch self {
        case .lessonGoals:
            return "1. Lektions- und Lernziele"
        case .studentLearningEvidence:
            return "2. Evidenz für Schülerlernen"
        case .instructionalStrategies:
            return "3. Unterrichtsstrategien"
        case .alternatives:
            return "4. Handlungsalternativen"
        }
    }

    public var promptDE: String {
        switch self {
        case .lessonGoals:
            return "Worin bestand das zentrale Lernziel dieser Sequenz? Welche Teilziele waren erkennbar?"
        case .studentLearningEvidence:
            return "Welche konkreten Beobachtungen (Äußerungen, Handlungen, Produkte) zeigen Fortschritt - oder fehlenden Fortschritt - der Lernenden?"
        case .instructionalStrategies:
            return "Welche Strategien der Lehrperson haben das Lernen unterstützt, welche eher nicht? Belege am Video."
        case .alternatives:
            return "Welche alternativen Schritte wären möglich? Welche Wirkung auf das Lernen erwarten Sie?"
        }
    }

    /// Professional-vision facet hint (Seidel: describe / explain / predict).
    public var visionFacetDE: String {
        switch self {
        case .lessonGoals: return "Beschreiben / Einordnen"
        case .studentLearningEvidence: return "Wahrnehmen + Begründen"
        case .instructionalStrategies: return "Erklären (wirkung auf Lernen)"
        case .alternatives: return "Vorhersagen / Alternativen"
        }
    }
}

public struct ReflectionAnswers: Codable, Equatable, Sendable {
    public struct Values: Sendable {
        public var lessonGoals = ""
        public var studentLearningEvidence = ""
        public var instructionalStrategies = ""
        public var alternatives = ""
        public var updatedAt: Date?

        public init() {}
    }

    public var lessonGoals: String
    public var studentLearningEvidence: String
    public var instructionalStrategies: String
    public var alternatives: String
    public var updatedAt: Date?

    public init(_ values: Values = Values()) {
        lessonGoals = values.lessonGoals
        studentLearningEvidence = values.studentLearningEvidence
        instructionalStrategies = values.instructionalStrategies
        alternatives = values.alternatives
        updatedAt = values.updatedAt
    }

    public subscript(prompt: ReflectionPromptID) -> String {
        get {
            switch prompt {
            case .lessonGoals: return lessonGoals
            case .studentLearningEvidence: return studentLearningEvidence
            case .instructionalStrategies: return instructionalStrategies
            case .alternatives: return alternatives
            }
        }
        set {
            switch prompt {
            case .lessonGoals: lessonGoals = newValue
            case .studentLearningEvidence: studentLearningEvidence = newValue
            case .instructionalStrategies: instructionalStrategies = newValue
            case .alternatives: alternatives = newValue
            }
            updatedAt = Date()
        }
    }

    public var filledCount: Int {
        ReflectionPromptID.allCases.filter { !self[$0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    public var isComplete: Bool {
        filledCount == ReflectionPromptID.allCases.count
    }
}

public struct ReflectionScaffold: Sendable {
    public init() {}

    public var prompts: [ReflectionPromptID] { ReflectionPromptID.allCases }

    public func validate(_ answers: ReflectionAnswers) -> [ReflectionPromptID] {
        prompts.filter { answers[$0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
