import Foundation
import SessionCore

@MainActor
extension AppSessionModel {
/// Attaches final media metadata to the originating transaction, never the selected session.
func attachRecording(
    for transaction: RecordingTransaction,
    finalizedURL: URL,
    runtimeStatus: CaptureRuntimeStatus
) async -> Bool {
    do {
        let context = try await recordingFinalizationContext(
            for: transaction,
            finalizedURL: finalizedURL
        )
        let persisted = try await finalizeRecording(
            context,
            runtimeStatus: runtimeStatus
        )
        if session.id == persisted.id {
            applyPersistedSession(persisted)
            mediaURLs[context.manifest.mediaAssetID] = context.canonicalURL
        }
        invalidateCachedPackages(for: persisted.id)
        await reloadListAsync()
        return true
    } catch {
        let message = error.localizedDescription
        await recordingDidFail(transaction, reason: message)
        lastStoreError = message
        return false
    }
}

    private struct RecordingFinalizationContext {
        let initial: CaptureSession
        let manifest: CaptureTakeManifest
        let authorization: CaptureAuthorizationSnapshot
        let endedAt: Date
        let canonicalURL: URL
    }

    private struct FinalizedMetadataInput {
        let metadata: MediaInspector.Metadata
        let endedAt: Date
        let finalRoute: String
        let canonicalURL: URL
    }

    private func recordingFinalizationContext(
        for transaction: RecordingTransaction,
        finalizedURL: URL
    ) async throws -> RecordingFinalizationContext {
        guard let initial = try await asyncStore.load(id: transaction.sessionID),
              let manifest = initial.takeManifests.first(where: { $0.id == transaction.transactionID }),
              let authorization = manifest.authorization,
              Self.isFinalizable(manifest)
        else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [
                NSLocalizedDescriptionKey: "Abgeschlossene Aufnahme konnte keinem vorbereiteten Take zugeordnet werden."
            ])
        }
        guard initial.authorizes(authorization, at: Date()) else {
            throw CocoaError(.fileWriteNoPermission, userInfo: [
                NSLocalizedDescriptionKey: "Die eingefrorene Aufnahmefreigabe war bei der Finalisierung nicht mehr aktiv."
            ])
        }
        let canonicalURL = try await asyncStore.prepareRecordingURL(for: initial)
        guard finalizedURL.standardizedFileURL == canonicalURL.standardizedFileURL else {
            throw CocoaError(.fileWriteInvalidFileName, userInfo: [
                NSLocalizedDescriptionKey: "Abgeschlossene Aufnahme hat keinen gültigen Sitzungsdateinamen."
            ])
        }
        try await asyncStore.secureFinalizedRecording(at: canonicalURL)
        return RecordingFinalizationContext(
            initial: initial,
            manifest: manifest,
            authorization: authorization,
            endedAt: Date(),
            canonicalURL: canonicalURL
        )
    }

    nonisolated private static func isFinalizable(_ manifest: CaptureTakeManifest) -> Bool {
        switch manifest.effectiveLifecycleState {
        case .prepared, .recording, .completionUnknown:
            true
        case .finalized, .failed:
            false
        }
    }

    private func finalizeRecording(
        _ context: RecordingFinalizationContext,
        runtimeStatus: CaptureRuntimeStatus
    ) async throws -> CaptureSession {
        let metadata = try await mediaInspector.inspect(url: context.canonicalURL)
        return try await asyncStore.mutateSession(
            id: context.initial.id,
            includeJournals: true
        ) { target in
            guard let manifestIndex = target.takeManifests.firstIndex(where: { $0.id == context.manifest.id }),
                  Self.isFinalizable(target.takeManifests[manifestIndex]),
                  target.authorizes(context.authorization, at: context.endedAt)
            else {
                throw CocoaError(.fileWriteNoPermission, userInfo: [
                    NSLocalizedDescriptionKey: "Die eingefrorene Aufnahmefreigabe ist bei der Finalisierung nicht mehr aktiv."
                ])
            }
            guard let assetIndex = target.mediaAssets.firstIndex(where: {
                $0.id == target.takeManifests[manifestIndex].mediaAssetID
            }) else {
                throw CocoaError(.fileReadCorruptFile, userInfo: [
                    NSLocalizedDescriptionKey: "Medienmanifest und Aufnahme stimmen nicht überein."
                ])
            }
            Self.applyFinalizedMetadata(
                FinalizedMetadataInput(
                    metadata: metadata,
                    endedAt: context.endedAt,
                    finalRoute: runtimeStatus.audioRoute,
                    canonicalURL: context.canonicalURL
                ),
                to: &target,
                manifestIndex: manifestIndex,
                assetIndex: assetIndex
            )
        }
    }

    nonisolated private static func applyFinalizedMetadata(
        _ input: FinalizedMetadataInput,
        to session: inout CaptureSession,
        manifestIndex: Int,
        assetIndex: Int
    ) {
        session.recordingRelativePath = input.canonicalURL.lastPathComponent
        session.mediaAssets[assetIndex].durationMilliseconds = input.metadata.durationMilliseconds
        session.mediaAssets[assetIndex].sha256 = input.metadata.sha256
        session.mediaAssets[assetIndex].codec = input.metadata.codec
        session.mediaAssets[assetIndex].resolution = input.metadata.resolution
        session.mediaAssets[assetIndex].frameRate = input.metadata.frameRate
        session.takeManifests[manifestIndex].endedAt = input.endedAt
        session.takeManifests[manifestIndex].durationMilliseconds = input.metadata.durationMilliseconds
        session.takeManifests[manifestIndex].finalizedAt = input.endedAt
        session.takeManifests[manifestIndex].lifecycleState = .finalized
        session.takeManifests[manifestIndex].failureReason = nil
        session.takeManifests[manifestIndex].cameraConfiguration["actualCodec"] = input.metadata.codec ?? "unavailable"
        session.takeManifests[manifestIndex].cameraConfiguration["actualResolution"] = input.metadata.resolution ?? "unavailable"
        session.takeManifests[manifestIndex].cameraConfiguration["actualFrameRate"] = input.metadata.frameRate.map { String($0) } ?? "unavailable"
        session.takeManifests[manifestIndex].audioConfiguration["finalRoute"] = input.finalRoute
        session.closeCaptureTimeline(at: input.endedAt)
    }

func attachCaptureObservation(_ observation: CaptureObservation, for id: UUID) async {
    do {
        guard try await asyncStore.appendCaptureObservationIfAuthorized(
            observation,
            toSession: id,
            at: observation.observedAt
        ) else { return }
        applyCaptureObservation(observation, to: id)
        invalidateCachedPackages(for: id)
    } catch {
        lastStoreError = error.localizedDescription
    }
}

private func applyCaptureObservation(_ observation: CaptureObservation, to id: UUID) {
    guard session.id == id else { return }
    if !session.captureObservations.contains(where: { $0.id == observation.id }) {
        session.captureObservations.append(observation)
    }
    session.updatedAt = max(session.updatedAt, observation.observedAt)
}
}
