import Foundation
import GuidanceEngine
import CryptoKit

/// The data schema written by the current SessionCore implementation.
public enum SessionSchema: Sendable {
    public static let currentVersion = 2
}

/// Normal operation never presents automated pedagogical hypotheses as validated evidence.
public enum OperatingMode: String, Codable, CaseIterable, Sendable {
    case evidenceSafe
    case experimentalResearch
}

/// Investigator-supplied reference required before experimental hypotheses may be enabled.
public struct ResearchProtocolReference: Codable, Equatable, Sendable {
    public var protocolIdentifier: String
    public var oversightReference: String
    public var expiresAt: Date
    public var disclosureAcknowledgedAt: Date

    public init(
        protocolIdentifier: String,
        oversightReference: String,
        expiresAt: Date,
        disclosureAcknowledgedAt: Date = Date()
    ) {
        self.protocolIdentifier = protocolIdentifier
        self.oversightReference = oversightReference
        self.expiresAt = expiresAt
        self.disclosureAcknowledgedAt = disclosureAcknowledgedAt
    }

    public func isUsable(at date: Date = Date()) -> Bool {
        !protocolIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !oversightReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && disclosureAcknowledgedAt <= date
            && expiresAt > date
    }
}

public enum MediaAssetRole: String, Codable, CaseIterable, Sendable {
    case ownRecorded
    case otherImported
}

/// A media item owned by a session. Paths are deliberately relative to the controlled store.
public struct SessionMediaAsset: Codable, Equatable, Identifiable, Sendable {
    public struct Values: Sendable {
        public var id = UUID()
        public var role: MediaAssetRole = .ownRecorded
        public var relativePath = ""
        public var originalFileName: String?
        public var durationMilliseconds: Int64?
        public var sha256: String?
        public var codec: String?
        public var resolution: String?
        public var frameRate: Double?
        public var createdAt = Date()

        public init() {}
    }

    public var id: UUID
    public var role: MediaAssetRole
    public var relativePath: String
    public var originalFileName: String?
    public var durationMilliseconds: Int64?
    public var sha256: String?
    public var codec: String?
    public var resolution: String?
    public var frameRate: Double?
    public var createdAt: Date

    public init(_ values: Values = Values()) {
        id = values.id
        role = values.role
        relativePath = values.relativePath
        originalFileName = values.originalFileName
        durationMilliseconds = values.durationMilliseconds.map { max(0, $0) }
        sha256 = values.sha256
        codec = values.codec
        resolution = values.resolution
        frameRate = values.frameRate
        createdAt = values.createdAt
    }
}

public struct EvidenceAnnotation: Codable, Equatable, Identifiable, Sendable {
    public struct Values: Sendable {
        public var id = UUID()
        public var promptIdentifier = ""
        public var mediaAssetID = UUID()
        public var startMilliseconds: Int64 = 0
        public var endMilliseconds: Int64?
        public var note = ""
        public var authorPseudonym = ""
        public var createdAt = Date()
        public var revisedAt = Date()
        public var lockedAt: Date?

        public init() {}
    }

    public var id: UUID
    public var promptIdentifier: String
    public var mediaAssetID: UUID
    public var startMilliseconds: Int64
    public var endMilliseconds: Int64
    public var note: String
    public var authorPseudonym: String
    public var createdAt: Date
    public var revisedAt: Date
    public var lockedAt: Date?

    public init(_ values: Values = Values()) {
        id = values.id
        promptIdentifier = values.promptIdentifier
        mediaAssetID = values.mediaAssetID
        startMilliseconds = max(0, values.startMilliseconds)
        endMilliseconds = max(max(0, values.startMilliseconds), values.endMilliseconds ?? values.startMilliseconds)
        note = values.note
        authorPseudonym = values.authorPseudonym
        createdAt = values.createdAt
        revisedAt = values.revisedAt
        lockedAt = values.lockedAt
    }
}

public enum ConsentScope: String, Codable, CaseIterable, Hashable, Sendable {
    case collection
    case localReflection
    case researchProcessing
    case secondaryUse
    case externalSharing
}

public struct RetentionPolicy: Codable, Equatable, Sendable {
    public var retainUntil: Date?
    public var actionAfterExpiry: String

    public init(retainUntil: Date? = nil, actionAfterExpiry: String = "manualReview") {
        self.retainUntil = retainUntil
        self.actionAfterExpiry = actionAfterExpiry
    }
}

public enum ExportEventStatus: String, Codable, Sendable {
    case attempted
    case completed
    case cancelled
    case failed
    case outcomeUnknown
}

/// Durable disclosure outbox entry. It is written before the system share sheet is shown and
/// then transitioned from `attempted` to a terminal state without re-authorizing an event that
/// has already happened.
public struct ExportEvent: Codable, Equatable, Identifiable, Sendable {
    public struct Values: Sendable {
        public var id = UUID()
        public var exportedAt = Date()
        public var operatorPseudonym = ""
        public var operatorAuthenticationMethod: String?
        public var includedScopes: Set<ConsentScope> = []
        public var fileDigests: [String: String] = [:]
        public var shareActivityIdentifier = "pending"
        public var status: ExportEventStatus = .completed
        public var completedAt: Date?
        public var failureDescription: String?

        public init() {}
    }

    public var id: UUID
    public var exportedAt: Date
    public var operatorPseudonym: String
    public var operatorAuthenticationMethod: String?
    public var includedScopes: Set<ConsentScope>
    public var fileDigests: [String: String]
    /// Identifier returned by the system share activity. It does not identify a recipient.
    public var shareActivityIdentifier: String
    public var status: ExportEventStatus
    public var completedAt: Date?
    public var failureDescription: String?

    public init(_ values: Values = Values()) {
        id = values.id
        exportedAt = values.exportedAt
        operatorPseudonym = values.operatorPseudonym
        operatorAuthenticationMethod = values.operatorAuthenticationMethod
        includedScopes = values.includedScopes
        fileDigests = values.fileDigests
        shareActivityIdentifier = values.shareActivityIdentifier
        status = values.status
        completedAt = values.completedAt ?? (values.status == .completed ? values.exportedAt : nil)
        failureDescription = values.failureDescription
    }

    private enum CodingKeys: String, CodingKey {
        case id, exportedAt, operatorPseudonym, operatorAuthenticationMethod, includedScopes, fileDigests
        case shareActivityIdentifier, status, completedAt, failureDescription
        case legacyRecipientCategory = "recipientCategory"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        exportedAt = try c.decode(Date.self, forKey: .exportedAt)
        operatorPseudonym = try c.decode(String.self, forKey: .operatorPseudonym)
        operatorAuthenticationMethod = try c.decodeIfPresent(String.self, forKey: .operatorAuthenticationMethod)
        includedScopes = try c.decode(Set<ConsentScope>.self, forKey: .includedScopes)
        fileDigests = try c.decode([String: String].self, forKey: .fileDigests)
        shareActivityIdentifier = try c.decodeIfPresent(
            String.self, forKey: .shareActivityIdentifier
        ) ?? c.decode(String.self, forKey: .legacyRecipientCategory)
        status = try c.decodeIfPresent(ExportEventStatus.self, forKey: .status) ?? .completed
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
            ?? (status == .completed ? exportedAt : nil)
        failureDescription = try c.decodeIfPresent(String.self, forKey: .failureDescription)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(exportedAt, forKey: .exportedAt)
        try c.encode(operatorPseudonym, forKey: .operatorPseudonym)
        try c.encodeIfPresent(operatorAuthenticationMethod, forKey: .operatorAuthenticationMethod)
        try c.encode(includedScopes, forKey: .includedScopes)
        try c.encode(fileDigests, forKey: .fileDigests)
        try c.encode(shareActivityIdentifier, forKey: .shareActivityIdentifier)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
        try c.encodeIfPresent(failureDescription, forKey: .failureDescription)
    }

    @discardableResult
    public mutating func finish(
        status: ExportEventStatus,
        shareActivityIdentifier: String?,
        failureDescription: String?,
        at date: Date = Date()
    ) -> Bool {
        guard status != .attempted, self.status == .attempted else { return false }
        self.status = status
        let activity = shareActivityIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.shareActivityIdentifier = activity.isEmpty ? "system-share" : activity
        self.failureDescription = failureDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        completedAt = date
        return true
    }
}

/// Immutable record of the exact decision that started a take.
public struct CaptureDecision: Codable, Equatable, Sendable {
    public struct Values: Sendable {
        public var decidedAt = Date()
        public var blockers: [String] = []
        public var overrideReason: String?
        public var operatorPseudonym = ""
        public var operatingMode: OperatingMode = .evidenceSafe
        public var operatorAuthenticationMethod: String?

        public init() {}
    }

    public let decidedAt: Date
    public let blockers: [String]
    public let overrideReason: String?
    public let operatorPseudonym: String
    public let operatingMode: OperatingMode
    /// Access gate used for the privileged capture action; a pseudonym is not authentication.
    public let operatorAuthenticationMethod: String?

    public init(_ values: Values = Values()) {
        decidedAt = values.decidedAt
        blockers = values.blockers.sorted()
        overrideReason = values.overrideReason?.trimmingCharacters(in: .whitespacesAndNewlines)
        operatorPseudonym = values.operatorPseudonym
        operatingMode = values.operatingMode
        operatorAuthenticationMethod = values.operatorAuthenticationMethod
    }

}

public enum CaptureTakeLifecycleState: String, Codable, Sendable {
    case prepared
    case recording
    case completionUnknown
    case finalized
    case failed
}

/// Consent authority frozen at preparation time so later capture callbacks cannot silently use
/// a different grant. `effectiveExpiresAt == nil` means none of the authorizing grants expires.
public struct CaptureAuthorizationSnapshot: Codable, Equatable, Sendable {
    public struct Values: Sendable {
        public var requiredScopes: Set<ConsentScope> = []
        public var grantIDs: [UUID] = []
        public var grantIDByScope: [ConsentScope: UUID] = [:]
        public var effectiveExpiresAt: Date?
        public var preparedAt = Date()
        public var researchProtocolIdentifier: String?

        public init() {}
    }

    public var requiredScopes: Set<ConsentScope>
    public var grantIDs: [UUID]
    /// Immutable scope-to-grant assignment used to revalidate a prepared capture. An empty
    /// binding denotes a legacy snapshot and is deliberately not authorization-capable.
    public var grantIDByScope: [ConsentScope: UUID]
    public var effectiveExpiresAt: Date?
    public var preparedAt: Date
    public var researchProtocolIdentifier: String?

    public init(_ values: Values = Values()) {
        requiredScopes = values.requiredScopes
        grantIDs = Array(Set(values.grantIDs)).sorted { $0.uuidString < $1.uuidString }
        grantIDByScope = values.grantIDByScope
        effectiveExpiresAt = values.effectiveExpiresAt
        preparedAt = values.preparedAt
        researchProtocolIdentifier = values.researchProtocolIdentifier
    }

    private enum CodingKeys: String, CodingKey {
        case requiredScopes, grantIDs, grantIDByScope, effectiveExpiresAt, preparedAt, researchProtocolIdentifier
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        requiredScopes = try container.decode(Set<ConsentScope>.self, forKey: .requiredScopes)
        grantIDs = try container.decode([UUID].self, forKey: .grantIDs)
        // Snapshots written before exact bindings existed remain readable, but fail closed
        // during authorization revalidation.
        grantIDByScope = try container.decodeIfPresent([ConsentScope: UUID].self, forKey: .grantIDByScope) ?? [:]
        effectiveExpiresAt = try container.decodeIfPresent(Date.self, forKey: .effectiveExpiresAt)
        preparedAt = try container.decode(Date.self, forKey: .preparedAt)
        researchProtocolIdentifier = try container.decodeIfPresent(String.self, forKey: .researchProtocolIdentifier)
    }
}
