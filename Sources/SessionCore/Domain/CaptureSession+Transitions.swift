import Foundation

/// Operator-supplied consent form state. Validation happens in `CaptureSession.replaceConsentGrants`.
public struct ConsentGrantDraft: Equatable, Sendable {
    public let scopes: Set<ConsentScope>
    public let documentIdentifier: String
    public let documentVersion: String
    public let participantGroupPseudonym: String
    public let expiresAt: Date?

    public init(
        scopes: Set<ConsentScope>,
        documentIdentifier: String,
        documentVersion: String,
        participantGroupPseudonym: String,
        expiresAt: Date?
    ) {
        self.scopes = scopes
        self.documentIdentifier = documentIdentifier
        self.documentVersion = documentVersion
        self.participantGroupPseudonym = participantGroupPseudonym
        self.expiresAt = expiresAt
    }
}

extension CaptureSession {
    /// Enters experimental research mode with the supplied protocol reference. The reference is
    /// stored as given; `hasUsableExperimentalProtocol(at:)` decides whether it is usable.
    public mutating func activateExperimentalMode(protocol reference: ResearchProtocolReference) {
        experimentalProtocol = reference
        operatingMode = .experimentalResearch
    }

    public mutating func returnToEvidenceSafe() {
        operatingMode = .evidenceSafe
        experimentalProtocol = nil
    }

    /// Replaces active scoped grants while retaining withdrawn records for auditability.
    /// Every active grant is withdrawn at `now`; a new grant is appended only for a complete draft.
    public mutating func replaceConsentGrants(with draft: ConsentGrantDraft, at now: Date) {
        for index in consentGrants.indices where consentGrants[index].withdrawnAt == nil {
            consentGrants[index].withdrawnAt = now
        }
        let documentID = draft.documentIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let version = draft.documentVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let pseudonym = draft.participantGroupPseudonym.trimmingCharacters(in: .whitespacesAndNewlines)
        if !draft.scopes.isEmpty, !documentID.isEmpty, !version.isEmpty, !pseudonym.isEmpty {
            var values = ConsentGrant.Values()
            values.scopes = draft.scopes
            values.documentIdentifier = documentID
            values.documentVersion = version
            values.participantGroupPseudonym = pseudonym
            values.grantedAt = now
            values.expiresAt = draft.expiresAt
            consentGrants.append(ConsentGrant(values))
        }
    }

    public mutating func removeAnnotation(id: EvidenceAnnotation.ID) {
        evidenceAnnotations.removeAll { $0.id == id }
    }
}
