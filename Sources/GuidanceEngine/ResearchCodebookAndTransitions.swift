import Foundation

// MARK: - Preset research checklist (L1)

public extension TeachingSituationPreset {
    /// Actionable research-capture checklist for this teaching situation (setup / pre-roll).
    var researchCaptureChecklistDE: [String] {
        var items: [String] = []
        if requiresBoard {
            items.append("Schreibfläche multi-cue sichtbar (Bar ≥ \(pct(minResearchBoardScore))).")
            if minResearchBoardTextDensity > 0.05 {
                items.append("Tafel-Text/Zielsichtbarkeit (Text-Dichte ≥ \(pct(minResearchBoardTextDensity))).")
            }
            if coPresenceEmphasis >= 0.55 {
                items.append("Person–Tafel Co-Präsenz (Bar ≥ \(pct(minResearchCoPresence))).")
            }
        } else {
            items.append("Schreibfläche optional - Akteure und Interaktionsraum priorisieren.")
        }
        if minPeople > 0 {
            items.append("Mindestens \(minPeople) Akteure im Bild.")
        }
        if prefersMultiPerson {
            items.append("Mehrpersonen-Cluster / Raumübersicht (Interaktionsdichte ≥ \(pct(minResearchInteractionDensity))).")
        } else if minPeople >= 2 {
            items.append("Dialog-/Paar-Interaktion lesbar (Dichte ≥ \(pct(minResearchInteractionDensity))).")
        }
        if !preferredLayouts.isEmpty {
            items.append("Layout: \(preferredLayouts.map(\.titleDE).joined(separator: " / ")) (Fit ≥ \(pct(minResearchLayoutFit))).")
        }
        items.append("Szene muss Preset „\(titleDE)“ matchen (nicht nur Platzierung/Gyro).")
        items.append("Stativ- und CV-Beobachtungsstabilität für kontinuierlichen Take (Derry).")
        return items
    }

    /// TIMSS-script family tag for comparative research documentation.
    var timssScriptFamilyDE: String {
        TeachingSituationCatalogue.family(for: id)
    }

    private func pct(_ v: Double) -> String {
        "\(Int((v * 100).rounded())) %"
    }
}

// MARK: - Scene transition detector (L2)

/// Detects teaching-scene / layout / TIMSS-primary changes for continuous-take research logs.
public struct SceneTransitionEvent: Equatable, Codable, Sendable, Identifiable {
    public var id: UUID
    public var at: Date
    public var fromScene: String
    public var toScene: String
    public var fromLayout: String
    public var toLayout: String
    public var fromTIMSS: String?
    public var toTIMSS: String?
    public var noteDE: String

    public struct Values: Sendable {
        public var id = UUID()
        public var at = Date()
        public var fromScene = ""
        public var toScene = ""
        public var fromLayout = ""
        public var toLayout = ""
        public var fromTIMSS: String?
        public var toTIMSS: String?
        public var noteDE = ""

        public init() {}
    }

    public init(_ values: Values) {
        id = values.id
        at = values.at
        fromScene = values.fromScene
        toScene = values.toScene
        fromLayout = values.fromLayout
        toLayout = values.toLayout
        fromTIMSS = values.fromTIMSS
        toTIMSS = values.toTIMSS
        noteDE = values.noteDE
    }
}

public struct SceneTransitionDetector: Equatable, Sendable {
    public private(set) var lastScene: TeachingSceneType?
    public private(set) var lastLayout: ClassroomLayoutPattern?
    public private(set) var lastTIMSS: TIMSSActivityCode?
    public private(set) var events: [SceneTransitionEvent]
    public var maxEvents: Int

    public init(maxEvents: Int = 32) {
        self.lastScene = nil
        self.lastLayout = nil
        self.lastTIMSS = nil
        self.events = []
        self.maxEvents = max(4, maxEvents)
    }

    public mutating func reset() {
        lastScene = nil
        lastLayout = nil
        lastTIMSS = nil
        events.removeAll()
    }

    /// Observe scene (+ optional coding); returns a transition event if structure changed.
    @discardableResult
    public mutating func observe(
        scene: TeachingSceneAssessment,
        coding: PedagogicalCodingResult? = nil,
        at date: Date = Date()
    ) -> SceneTransitionEvent? {
        let sceneType = scene.sceneType
        let layout = scene.layoutPattern
        let timss = coding?.primaryTIMSS

        defer {
            lastScene = sceneType
            lastLayout = layout
            if let timss { lastTIMSS = timss }
        }

        guard let prevScene = lastScene, let prevLayout = lastLayout else {
            return nil
        }

        let input = TransitionInput(
            fromScene: prevScene,
            toScene: sceneType,
            fromLayout: prevLayout,
            toLayout: layout,
            fromTIMSS: lastTIMSS,
            toTIMSS: timss
        )
        let transition = transitionDetails(input)
        guard transition.changed else { return nil }
        var values = SceneTransitionEvent.Values()
        values.at = date
        values.fromScene = prevScene.rawValue
        values.toScene = sceneType.rawValue
        values.fromLayout = prevLayout.rawValue
        values.toLayout = layout.rawValue
        values.fromTIMSS = lastTIMSS?.rawValue
        values.toTIMSS = timss?.rawValue
        values.noteDE = transition.noteDE
        let event = SceneTransitionEvent(values)
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        return event
    }

    private struct TransitionInput {
        let fromScene: TeachingSceneType
        let toScene: TeachingSceneType
        let fromLayout: ClassroomLayoutPattern
        let toLayout: ClassroomLayoutPattern
        let fromTIMSS: TIMSSActivityCode?
        let toTIMSS: TIMSSActivityCode?
    }

    private func transitionDetails(_ input: TransitionInput) -> (changed: Bool, noteDE: String) {
        let sceneChanged = input.fromScene != input.toScene
        let layoutChanged = input.fromLayout != input.toLayout
        let timssChanged = input.fromTIMSS != nil && input.toTIMSS != nil && input.fromTIMSS != input.toTIMSS
        let changed = sceneChanged || layoutChanged || timssChanged
        return (changed, transitionNote(
            sceneChanged: sceneChanged,
            layoutChanged: layoutChanged,
            timssChanged: timssChanged,
            input: input
        ))
    }

    private func transitionNote(
        sceneChanged: Bool,
        layoutChanged: Bool,
        timssChanged: Bool,
        input: TransitionInput
    ) -> String {
        var parts: [String] = []
        if sceneChanged { parts.append("Szene \(input.fromScene.titleDE) → \(input.toScene.titleDE)") }
        if layoutChanged { parts.append("Layout \(input.fromLayout.titleDE) → \(input.toLayout.titleDE)") }
        if timssChanged, let fromTIMSS = input.fromTIMSS, let toTIMSS = input.toTIMSS {
            parts.append("TIMSS \(fromTIMSS.titleDE) → \(toTIMSS.titleDE)")
        }
        return parts.joined(separator: "; ")
    }
}


/// One-shot unvalidated rule-set summary from the full guidance stack.
public struct ResearchReadinessReport: Equatable, Sendable {
    public var teachingSituation: TeachingSituationID
    public var placementOK: Bool
    public var sceneMatchesPreset: Bool
    public var structureSufficient: Bool
    public var researchQualityLevel: ResearchCaptureQuality.Level
    public var researchQualityScore: Double
    public var structureScore: Double
    public var primaryTIMSS: TIMSSActivityCode
    public var primaryGTI: GTIQualityCode
    public var ipnCount: Int
    public var gtiCount: Int
    public var unvalidatedRulesPass: Bool
    public var summaryDE: String
    public var checklistOpenDE: [String]

    public struct Values: Sendable {
        public var teachingSituation: TeachingSituationID = .frontalBoardInstruction
        public var placementOK = false
        public var sceneMatchesPreset = false
        public var structureSufficient = false
        public var researchQualityLevel: ResearchCaptureQuality.Level = .unsuitable
        public var researchQualityScore = 0.0
        public var structureScore = 0.0
        public var primaryTIMSS: TIMSSActivityCode = .unclearOrNonInstructional
        public var primaryGTI: GTIQualityCode = .instructionalQuality
        public var ipnCount = 0
        public var gtiCount = 0
        public var unvalidatedRulesPass = false
        public var summaryDE = ""
        public var checklistOpenDE: [String] = []

        public init() {}
    }

    public init(_ values: Values) {
        teachingSituation = values.teachingSituation
        placementOK = values.placementOK
        sceneMatchesPreset = values.sceneMatchesPreset
        structureSufficient = values.structureSufficient
        researchQualityLevel = values.researchQualityLevel
        researchQualityScore = values.researchQualityScore
        structureScore = values.structureScore
        primaryTIMSS = values.primaryTIMSS
        primaryGTI = values.primaryGTI
        ipnCount = values.ipnCount
        gtiCount = values.gtiCount
        unvalidatedRulesPass = values.unvalidatedRulesPass
        summaryDE = values.summaryDE
        checklistOpenDE = values.checklistOpenDE
    }

    public static func build(from result: GuidanceResult) -> ResearchReadinessReport {
        let preset = TeachingSituationCatalogue.preset(for: result.teachingSituation)
        let status = readinessStatus(for: result)
        let rq = result.researchQuality
        let open = result.structureSufficiency.failedChecks.map { "\($0.labelDE): \($0.detailDE)" }
        var values = Values()
        values.teachingSituation = result.teachingSituation
        values.placementOK = status.placementOK
        values.sceneMatchesPreset = status.sceneOK
        values.structureSufficient = status.structureOK
        values.researchQualityLevel = rq.level
        values.researchQualityScore = rq.score
        values.structureScore = result.structureSufficiency.score
        values.primaryTIMSS = result.pedagogicalCoding.primaryTIMSS
        values.primaryGTI = result.pedagogicalCoding.primaryGTI
        values.ipnCount = result.pedagogicalCoding.ipnDimensions.count
        values.gtiCount = result.pedagogicalCoding.gtiDimensions.count
        values.unvalidatedRulesPass = status.ready
        values.summaryDE = readinessSummary(
            result: result,
            preset: preset,
            status: status
        )
        values.checklistOpenDE = open
        return ResearchReadinessReport(values)
    }

    struct ReadinessStatus {
        let placementOK: Bool
        let sceneOK: Bool
        let structureOK: Bool
        let ready: Bool
    }

    private static func readinessStatus(for result: GuidanceResult) -> ReadinessStatus {
        let placementOK = result.placement.quality == .directSignalsPass
        let sceneOK = result.scene.matchesPreset
        let structureOK = result.structureSufficiency.sufficient
        let status = ReadinessStatus(
            placementOK: placementOK,
            sceneOK: sceneOK,
            structureOK: structureOK,
            ready: false
        )
        return ReadinessStatus(
            placementOK: placementOK,
            sceneOK: sceneOK,
            structureOK: structureOK,
            ready: readinessRequirementsAreMet(status, result: result)
        )
    }

    private static func readinessSummary(
        result: GuidanceResult,
        preset: TeachingSituationPreset,
        status: ReadinessStatus
    ) -> String {
        if status.ready {
            return "Unvalidierte Regelprüfung für „\(preset.titleDE)“ erfüllt: Platzierung, Szenenregel, Strukturregel und Kodierregeln aktiv (TIMSS \(result.pedagogicalCoding.primaryTIMSS.titleDE), GTI \(result.pedagogicalCoding.primaryGTI.titleDE)). Keine Aussage zur wissenschaftlichen Nutzbarkeit."
        }
        let failures = readinessFailures(status, result: result)
        return "Unvalidierte Regelprüfung nicht erfüllt (\(failures.isEmpty ? "grenzwertig" : failures)). \(result.structureSufficiency.summaryDE)"
    }

    private static func readinessRequirementsAreMet(
        _ status: ReadinessStatus,
        result: GuidanceResult
    ) -> Bool {
        hasPassingPlacementSceneAndStructure(status)
            && hasEligibleQualityAndRecordability(result)
    }

    private static func readinessFailures(
        _ status: ReadinessStatus,
        result: GuidanceResult
    ) -> String {
        [
            status.placementOK ? nil : "Platzierung",
            status.sceneOK ? nil : "Szene/Preset",
            status.structureOK ? nil : "Struktur",
            result.researchQuality.level != .unsuitable ? nil : "Forschungsqualität"
        ].compactMap { $0 }.joined(separator: ", ")
    }
}
