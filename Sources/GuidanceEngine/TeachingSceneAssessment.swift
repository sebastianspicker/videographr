import Foundation

/// Result of an unvalidated teaching-scene rule applied to CV and frame structure.
public struct TeachingSceneAssessment: Equatable, Sendable {
    public var sceneType: TeachingSceneType
    /// Confidence in the primary scene label 0...1.
    public var confidence: Double
    /// How well the observed scene matches the selected teaching-situation preset 0...1.
    public var presetMatchScore: Double
    /// Whether the scene is considered a match (expected or acceptable) for the preset.
    public var matchesPreset: Bool
    public var summaryDE: String
    /// Secondary signals for debugging / coding priors.
    public var boardSignal: Double
    public var peopleSignal: Double
    public var coPresenceSignal: Double
    public var multiPersonSignal: Double
    /// Layout-structure signal (spread/cluster/pattern fit). 0...1
    public var layoutSignal: Double
    public var layoutPattern: ClassroomLayoutPattern

    public struct Classification: Equatable, Sendable {
        public var sceneType: TeachingSceneType
        public var confidence: Double
        public var presetMatchScore: Double
        public var matchesPreset: Bool

        public init(
            sceneType: TeachingSceneType,
            confidence: Double,
            presetMatchScore: Double,
            matchesPreset: Bool
        ) {
            self.sceneType = sceneType
            self.confidence = confidence
            self.presetMatchScore = presetMatchScore
            self.matchesPreset = matchesPreset
        }
    }

    public struct PeopleSignals: Equatable, Sendable {
        public var peopleSignal: Double
        public var coPresenceSignal: Double
        public var multiPersonSignal: Double

        public init(peopleSignal: Double = 0, coPresenceSignal: Double = 0, multiPersonSignal: Double = 0) {
            self.peopleSignal = peopleSignal
            self.coPresenceSignal = coPresenceSignal
            self.multiPersonSignal = multiPersonSignal
        }
    }

    public struct StructureSignals: Equatable, Sendable {
        public var boardSignal: Double
        public var layoutSignal: Double
        public var layoutPattern: ClassroomLayoutPattern

        public init(
            boardSignal: Double = 0,
            layoutSignal: Double = 0,
            layoutPattern: ClassroomLayoutPattern = .unknown
        ) {
            self.boardSignal = boardSignal
            self.layoutSignal = layoutSignal
            self.layoutPattern = layoutPattern
        }
    }

    public struct Values: Equatable, Sendable {
        public var classification: Classification
        public var summaryDE: String
        public var peopleSignals: PeopleSignals
        public var structureSignals: StructureSignals

        public init(
            classification: Classification,
            summaryDE: String,
            peopleSignals: PeopleSignals = .init(),
            structureSignals: StructureSignals = .init()
        ) {
            self.classification = classification
            self.summaryDE = summaryDE
            self.peopleSignals = peopleSignals
            self.structureSignals = structureSignals
        }
    }

    public init(_ values: Values) {
        sceneType = values.classification.sceneType
        confidence = min(1, max(0, values.classification.confidence))
        presetMatchScore = min(1, max(0, values.classification.presetMatchScore))
        matchesPreset = values.classification.matchesPreset
        summaryDE = values.summaryDE
        boardSignal = min(1, max(0, values.structureSignals.boardSignal))
        peopleSignal = min(1, max(0, values.peopleSignals.peopleSignal))
        coPresenceSignal = min(1, max(0, values.peopleSignals.coPresenceSignal))
        multiPersonSignal = min(1, max(0, values.peopleSignals.multiPersonSignal))
        layoutSignal = min(1, max(0, values.structureSignals.layoutSignal))
        layoutPattern = values.structureSignals.layoutPattern
    }

    public static let unavailable = TeachingSceneAssessment(
        .init(
            classification: .init(
                sceneType: .emptyOrUnusable,
                confidence: 0,
                presetMatchScore: 0,
                matchesPreset: false
            ),
            summaryDE: "Szenenanalyse nicht verfügbar (CV fehlgeschlagen oder leer)."
        )
    )
}
