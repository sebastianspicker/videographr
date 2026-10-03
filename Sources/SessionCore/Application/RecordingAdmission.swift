import Foundation

/// Pure recording-start admission: consent authority, protocol, take slot, override reason and
/// readiness. The check order is part of the contract because the first refusal is shown to the operator.
public enum RecordingAdmission {
    public struct Admission: Equatable, Sendable {
        public let authorization: CaptureAuthorizationSnapshot
        public let decision: CaptureDecision

        public init(authorization: CaptureAuthorizationSnapshot, decision: CaptureDecision) {
            self.authorization = authorization
            self.decision = decision
        }
    }

    public enum Refusal: Error, Equatable, Sendable {
        case authorizationMissing
        case authorizationExpiresSoon
        case experimentalProtocolUnusable
        case recordingSlotOccupied
        case overrideReasonMissing
        case notReady(summaryDE: String)

        public var messageDE: String {
            switch self {
            case .authorizationMissing:
                return "Aufnahme blockiert: aktiver lokaler Freigabedatensatz für Erhebung und Reflexion fehlt."
            case .authorizationExpiresSoon:
                return "Aufnahme blockiert: die früheste erforderliche Freigabe läuft in weniger als 45 Sekunden ab."
            case .experimentalProtocolUnusable:
                return "Experimenteller Modus blockiert: Protokoll- oder Aufsichtsreferenz fehlt bzw. ist abgelaufen."
            case .recordingSlotOccupied:
                return "Diese Sitzung besitzt bereits eine eigene Aufnahme. Bitte eine neue Sitzung für einen weiteren Take anlegen."
            case .overrideReasonMissing:
                return "Für den Start trotz technischer Warnungen ist eine Begründung erforderlich."
            case .notReady(let summaryDE):
                return summaryDE
            }
        }
    }

    public static func evaluate(
        session: CaptureSession,
        readiness: SessionReadiness,
        runtimeStatus: CaptureRuntimeStatus,
        overrideReason: String,
        operatorPseudonym: String,
        operatorAuthenticationMethod: String,
        at now: Date
    ) -> Result<Admission, Refusal> {
        guard let authorization = session.captureAuthorizationSnapshot(at: now) else {
            return .failure(.authorizationMissing)
        }
        guard !authorizationExpiresSoon(authorization, at: now) else {
            return .failure(.authorizationExpiresSoon)
        }
        guard session.operatingMode != .experimentalResearch || session.hasUsableExperimentalProtocol(at: now) else {
            return .failure(.experimentalProtocolUnusable)
        }
        guard recordingSlotIsAvailable(in: session) else {
            return .failure(.recordingSlotOccupied)
        }

        let blockerIDs = recordingBlockers(readiness: readiness, runtimeStatus: runtimeStatus)
        let reason = overrideReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasOverrideReason(reason, for: blockerIDs) else {
            return .failure(.overrideReasonMissing)
        }
        guard recordingIsAllowed(by: readiness) else {
            return .failure(.notReady(summaryDE: readiness.summaryDE))
        }
        var values = CaptureDecision.Values()
        values.blockers = blockerIDs
        values.overrideReason = blockerIDs.isEmpty ? nil : reason
        values.operatorPseudonym = effectiveOperator(from: operatorPseudonym, in: session)
        values.operatingMode = session.operatingMode
        values.operatorAuthenticationMethod = operatorAuthenticationMethod
        return .success(Admission(authorization: authorization, decision: CaptureDecision(values)))
    }

    /// Persisted blocker identifiers: readiness raw values plus runtime-derived suffixes.
    public static func recordingBlockers(
        readiness: SessionReadiness,
        runtimeStatus: CaptureRuntimeStatus
    ) -> [String] {
        var blockerIDs = readiness.blockers.map(\.rawValue)
        if runtimeStatus.batteryPercent.map({ $0 <= CaptureRuntimeStatus.lowBatteryPercent }) == true { blockerIDs.append("batteryLow") }
        if ["ernst", "kritisch"].contains(runtimeStatus.thermalState) {
            blockerIDs.append("thermalState:\(runtimeStatus.thermalState)")
        }
        if !runtimeStatus.spokenAudioCheckCompleted {
            blockerIDs.append("spokenAudioPlaybackCheckMissing")
        }
        return blockerIDs
    }

    private static func authorizationExpiresSoon(
        _ authorization: CaptureAuthorizationSnapshot,
        at preparedAt: Date
    ) -> Bool {
        (authorization.effectiveExpiresAt?.timeIntervalSince(preparedAt) ?? 46) <= 45
    }

    private static func recordingSlotIsAvailable(in session: CaptureSession) -> Bool {
        !session.mediaAssets.contains(where: { $0.role == .ownRecorded })
            && session.recordingRelativePath == nil
    }

    private static func hasOverrideReason(_ reason: String, for blockers: [String]) -> Bool {
        blockers.isEmpty || !reason.isEmpty
    }

    private static func recordingIsAllowed(by readiness: SessionReadiness) -> Bool {
        readiness.canRecord || readiness.canOverrideQualityWarnings
    }

    private static func effectiveOperator(from operatorPseudonym: String, in session: CaptureSession) -> String {
        let operatorID = operatorPseudonym.trimmingCharacters(in: .whitespacesAndNewlines)
        return operatorID.isEmpty
            ? session.consentGrants.last(where: { $0.authorizes(.collection) })?.participantGroupPseudonym ?? "local-operator"
            : operatorID
    }
}
