import Foundation
import GuidanceEngine

/// Why a continuous local recording is blocked (German messages for Live UI).
public enum ReadinessBlocker: String, Equatable, Sendable, Identifiable {
    case consentMissing
    case contextIncomplete
    case visualSampleMissing
    case visualCritical
    case audioNotReady
    case titleMissing

    public var id: String { rawValue }

    public var messageDE: String {
        switch self {
        case .consentMissing:
            return "Freigabe für Erhebung und lokale Reflexion ist nicht aktiv."
        case .contextIncomplete:
            return "Kontext unvollständig (mindestens Fach und Stundenziel)."
        case .visualSampleMissing:
            return "Aktuelles direktes Bildsignal fehlt noch."
        case .visualCritical:
            return "Kritische Bild-/Lagehinweise (z. B. Gegenlicht, starke Schräglage, zu viel Decke)."
        case .audioNotReady:
            return "Audio nicht aufnahmebereit (zu leise, still oder übersteuert)."
        case .titleMissing:
            return "Sitzungstitel fehlt."
        }
    }
}

/// Aggregated pre-roll / mid-take readiness snapshot for the Live record control.
public struct SessionReadiness: Equatable, Sendable {
    public struct Values: Sendable {
        public var canRecord = false
        public var blockers: [ReadinessBlocker] = []
        public var visualSeverity: GuidanceSeverity = .ok
        public var audio = AudioGuidance(status: .silent, message: "", actionHint: "", isReady: false)
        public var setupComplete = false
        public var summaryDE = ""

        public init() {}
    }

    public var canRecord: Bool
    public var blockers: [ReadinessBlocker]
    public var visualSeverity: GuidanceSeverity
    public var audio: AudioGuidance
    public var setupComplete: Bool
    public var summaryDE: String

    public init(_ values: Values = Values()) {
        canRecord = values.canRecord
        blockers = values.blockers
        visualSeverity = values.visualSeverity
        audio = values.audio
        setupComplete = values.setupComplete
        summaryDE = values.summaryDE
    }

    /// A force-record UI may override quality/context warnings, never missing consent.
    public var canOverrideQualityWarnings: Bool {
        !blockers.contains(.consentMissing) && !blockers.contains(.visualSampleMissing)
    }
}

/// Combines scoped authorization, context, direct visual observability, and audio amplitude.
public struct ReadinessAggregator: Sendable {
    public var audioEvaluator: AudioReadinessEvaluator
    /// If true, critical visual tips block recording; warnings alone do not.
    public var blockOnVisualCritical: Bool
    public init(
        audioEvaluator: AudioReadinessEvaluator = .default,
        blockOnVisualCritical: Bool = true
    ) {
        self.audioEvaluator = audioEvaluator
        self.blockOnVisualCritical = blockOnVisualCritical
    }

    /// Evaluate whether a continuous take may start from direct, locally observed inputs.
    public func evaluate(
        session: CaptureSession,
        visual: GuidanceResult,
        audioSample: AudioLevelSample
    ) -> SessionReadiness {
        let audio = audioEvaluator.evaluate(audioSample)
        let blockers = readinessBlockers(session: session, visual: visual, audio: audio)
        let canRecord = blockers.isEmpty
        var values = SessionReadiness.Values()
        values.canRecord = canRecord
        values.blockers = blockers
        values.visualSeverity = visualSeverity(for: visual)
        values.audio = audio
        values.setupComplete = session.setupComplete
        values.summaryDE = readinessSummary(canRecord: canRecord, blockers: blockers)
        return SessionReadiness(values)
    }

    private func readinessBlockers(
        session: CaptureSession,
        visual: GuidanceResult,
        audio: AudioGuidance
    ) -> [ReadinessBlocker] {
        var blockers = sessionBlockers(session)
        if isWaitingForCurrentVisualSample(visual) { blockers.append(.visualSampleMissing) }
        if blockOnVisualCritical && hasDirectCaptureFailure(visual) { blockers.append(.visualCritical) }
        if !audio.isReady { blockers.append(.audioNotReady) }
        return blockers
    }

    private func sessionBlockers(_ session: CaptureSession) -> [ReadinessBlocker] {
        var blockers: [ReadinessBlocker] = []
        if session.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { blockers.append(.titleMissing) }
        if !session.authorizes(.collection) || !session.authorizes(.localReflection) { blockers.append(.consentMissing) }
        if !session.context.isMinimallyComplete { blockers.append(.contextIncomplete) }
        return blockers
    }

    private func hasDirectCaptureFailure(_ visual: GuidanceResult) -> Bool {
        visual.observability.dimensions.contains { ($0.id == "level" || $0.id == "exposure") && $0.status == .fail }
    }

    /// Capture owns the generation boundary and explicitly marks the period before its first
    /// accepted frame. This marker is not a quality warning: it means no current direct visual
    /// evidence exists yet, so recording cannot be overridden into starting.
    private func isWaitingForCurrentVisualSample(_ visual: GuidanceResult) -> Bool {
        visual.observability.dimensions.contains { $0.id == "currentFrame" && $0.status == .unavailable }
    }

    private func visualSeverity(for visual: GuidanceResult) -> GuidanceSeverity {
        let statuses = visual.observability.dimensions.map(\.status)
        if statuses.contains(.fail) { return .critical }
        if statuses.contains(.warn) || statuses.contains(.unavailable) { return .warning }
        return .ok
    }

    private func readinessSummary(canRecord: Bool, blockers: [ReadinessBlocker]) -> String {
        canRecord
            ? "Bereit zur kontinuierlichen Aufnahme (Einwilligung, Kontext, direkte Bildsignale und Audio)."
            : "Noch nicht bereit: " + blockers.map(\.messageDE).joined(separator: " ")
    }
}
