import Foundation

/// Storage-neutral media facts obtained at the App boundary after finalization.
public struct FinalizedMediaMetadata: Equatable, Sendable {
    public var durationMilliseconds: Int64
    public var sha256: String
    public var codec: String?
    public var resolution: String?
    public var frameRate: Double?

    public init(
        durationMilliseconds: Int64,
        sha256: String,
        codec: String?,
        resolution: String?,
        frameRate: Double?
    ) {
        self.durationMilliseconds = max(0, durationMilliseconds)
        self.sha256 = sha256
        self.codec = codec
        self.resolution = resolution
        self.frameRate = frameRate
    }
}

/// Immutable capture-owned values installed atomically when a recording is prepared.
public struct PreparedRecordingMutation: Sendable {
    public var transactionID: UUID
    public var asset: SessionMediaAsset
    public var decision: CaptureDecision
    public var manifest: CaptureTakeManifest
    public var provenance: BuildProvenance
    public var preparedAt: Date

    public init(
        transactionID: UUID,
        asset: SessionMediaAsset,
        decision: CaptureDecision,
        manifest: CaptureTakeManifest,
        provenance: BuildProvenance,
        preparedAt: Date
    ) {
        self.transactionID = transactionID
        self.asset = asset
        self.decision = decision
        self.manifest = manifest
        self.provenance = provenance
        self.preparedAt = preparedAt
    }
}

/// Pure transition rules for one prepared recording transaction.
///
/// Authorization, capacity, URL ownership, and media inspection deliberately stay at their
/// concrete boundaries. These rules mutate only session DTOs and make stale or terminal events
/// harmless no-ops.
public enum RecordingStateMachine {
    @discardableResult
    public static func prepare(
        _ mutation: PreparedRecordingMutation,
        in session: inout CaptureSession
    ) -> Bool {
        guard mutation.manifest.id == mutation.transactionID,
              mutation.manifest.sessionID == session.id,
              mutation.manifest.mediaAssetID == mutation.asset.id,
              !session.mediaAssets.contains(where: { $0.role == .ownRecorded }),
              session.recordingRelativePath == nil,
              !session.takeManifests.contains(where: { $0.id == mutation.transactionID })
        else { return false }
        session.captureDecisions.append(mutation.decision)
        session.mediaAssets.append(mutation.asset)
        session.takeManifests.append(mutation.manifest)
        session.buildProvenance = mutation.provenance
        session.updatedAt = max(session.updatedAt, mutation.preparedAt)
        return true
    }

    @discardableResult
    public static func began(
        transactionID: UUID,
        in session: inout CaptureSession,
        at date: Date
    ) -> Bool {
        guard let index = manifestIndex(for: transactionID, in: session),
              session.takeManifests[index].effectiveLifecycleState == .prepared
        else { return false }
        session.takeManifests[index].lifecycleState = .recording
        session.updatedAt = date
        return true
    }

    @discardableResult
    public static func completionUnknown(
        transactionID: UUID,
        in session: inout CaptureSession,
        at date: Date
    ) -> Bool {
        guard let index = manifestIndex(for: transactionID, in: session),
              [.prepared, .recording].contains(session.takeManifests[index].effectiveLifecycleState)
        else { return false }
        session.takeManifests[index].lifecycleState = .completionUnknown
        session.updatedAt = date
        return true
    }

    @discardableResult
    public static func finalized(
        transactionID: UUID,
        metadata: FinalizedMediaMetadata,
        finalRoute: String,
        canonicalFileName: String,
        in session: inout CaptureSession,
        at date: Date
    ) -> Bool {
        guard let manifestIndex = manifestIndex(for: transactionID, in: session),
              isFinalizable(session.takeManifests[manifestIndex]),
              let assetIndex = session.mediaAssets.firstIndex(where: {
                  $0.id == session.takeManifests[manifestIndex].mediaAssetID
              })
        else { return false }
        session.recordingRelativePath = canonicalFileName
        session.mediaAssets[assetIndex].durationMilliseconds = metadata.durationMilliseconds
        session.mediaAssets[assetIndex].sha256 = metadata.sha256
        session.mediaAssets[assetIndex].codec = metadata.codec
        session.mediaAssets[assetIndex].resolution = metadata.resolution
        session.mediaAssets[assetIndex].frameRate = metadata.frameRate
        session.takeManifests[manifestIndex].endedAt = date
        session.takeManifests[manifestIndex].durationMilliseconds = metadata.durationMilliseconds
        session.takeManifests[manifestIndex].finalizedAt = date
        session.takeManifests[manifestIndex].lifecycleState = .finalized
        session.takeManifests[manifestIndex].failureReason = nil
        session.takeManifests[manifestIndex].cameraConfiguration["actualCodec"] = metadata.codec ?? "unavailable"
        session.takeManifests[manifestIndex].cameraConfiguration["actualResolution"] = metadata.resolution ?? "unavailable"
        session.takeManifests[manifestIndex].cameraConfiguration["actualFrameRate"] = metadata.frameRate.map { String($0) } ?? "unavailable"
        session.takeManifests[manifestIndex].audioConfiguration["finalRoute"] = finalRoute
        session.closeCaptureTimeline(at: date)
        return true
    }

    @discardableResult
    public static func failed(
        transactionID: UUID,
        reason: String,
        in session: inout CaptureSession,
        at date: Date
    ) -> Bool {
        guard let index = manifestIndex(for: transactionID, in: session),
              ![.finalized, .failed].contains(session.takeManifests[index].effectiveLifecycleState)
        else { return false }
        let assetID = session.takeManifests[index].mediaAssetID
        let relativePath = session.mediaAssets.first(where: { $0.id == assetID })?.relativePath
        session.takeManifests[index].lifecycleState = .failed
        session.takeManifests[index].failureReason = reason
        session.takeManifests[index].endedAt = date
        session.mediaAssets.removeAll { $0.id == assetID }
        if session.recordingRelativePath == relativePath { session.recordingRelativePath = nil }
        session.closeCaptureTimeline(at: date)
        return true
    }

    public static func isFinalizable(_ manifest: CaptureTakeManifest) -> Bool {
        switch manifest.effectiveLifecycleState {
        case .prepared, .recording, .completionUnknown: true
        case .finalized, .failed: false
        }
    }

    private static func manifestIndex(for transactionID: UUID, in session: CaptureSession) -> Int? {
        session.takeManifests.firstIndex(where: { $0.id == transactionID })
    }
}
