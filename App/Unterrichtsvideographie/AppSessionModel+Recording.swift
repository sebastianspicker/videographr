import Foundation
import GuidanceEngine
import SessionCore
import UIKit

@MainActor
extension AppSessionModel {
func prepareSessionForRecording(_ preparation: RecordingPreparation) async -> PreparedRecording? {
    guard await flushPendingChanges() else { return nil }
    let preparedAt = Date()
    guard let authorization = preparedRecordingAuthorization(at: preparedAt),
          let decision = preparedCaptureDecision(for: preparation)
    else { return nil }

    do {
        let artifacts = try await makePreparedRecordingArtifacts(
            for: preparation,
            authorization: authorization,
            decision: decision,
            preparedAt: preparedAt
        )
        let persisted = try await persistPreparedRecording(artifacts)
        applyPersistedSession(persisted)
        invalidateCachedPackages(for: persisted.id)
        await reloadListAsync()
        return PreparedRecording(
            sessionID: persisted.id,
            transactionID: preparation.transactionID,
            mediaAssetID: artifacts.asset.id,
            url: artifacts.url,
            stagedURL: artifacts.stagedURL,
            authorization: authorization,
            plannedDurationMinutes: artifacts.session.plannedDurationMinutes
        )
    } catch {
        lastStoreError = error.localizedDescription
        return nil
    }
}

    private struct PreparedRecordingArtifacts {
        let session: CaptureSession
        let url: URL
        let stagedURL: URL
        let asset: SessionMediaAsset
        let decision: CaptureDecision
        let provenance: BuildProvenance
        let manifest: CaptureTakeManifest
        let preparedAt: Date
    }

    private struct PreparedRecordingManifestInput {
        let transactionID: UUID
        let session: CaptureSession
        let asset: SessionMediaAsset
        let decision: CaptureDecision
        let provenance: BuildProvenance
        let authorization: CaptureAuthorizationSnapshot
        let runtimeStatus: CaptureRuntimeStatus
    }

    private func preparedRecordingAuthorization(at preparedAt: Date) -> CaptureAuthorizationSnapshot? {
    guard let authorization = session.captureAuthorizationSnapshot(at: preparedAt) else {
        lastStoreError = "Aufnahme blockiert: aktiver lokaler Freigabedatensatz für Erhebung und Reflexion fehlt."
        return nil
    }
    guard recordingAuthorizationIsUsable(authorization, at: preparedAt) else { return nil }
    guard recordingSlotIsAvailable() else {
        lastStoreError = "Diese Sitzung besitzt bereits eine eigene Aufnahme. Bitte eine neue Sitzung für einen weiteren Take anlegen."
        return nil
    }
    return authorization
}

private func recordingAuthorizationIsUsable(_ authorization: CaptureAuthorizationSnapshot, at preparedAt: Date) -> Bool {
    guard !authorizationExpiresSoon(authorization, at: preparedAt) else {
        lastStoreError = "Aufnahme blockiert: die früheste erforderliche Freigabe läuft in weniger als 45 Sekunden ab."
        return false
    }
    guard session.operatingMode != .experimentalResearch || session.hasUsableExperimentalProtocol else {
        lastStoreError = "Experimenteller Modus blockiert: Protokoll- oder Aufsichtsreferenz fehlt bzw. ist abgelaufen."
        return false
    }
    return true
}

    private func authorizationExpiresSoon(
        _ authorization: CaptureAuthorizationSnapshot,
        at preparedAt: Date
    ) -> Bool {
        (authorization.effectiveExpiresAt?.timeIntervalSince(preparedAt) ?? 46) <= 45
    }

    private func recordingSlotIsAvailable() -> Bool {
        !session.mediaAssets.contains(where: { $0.role == .ownRecorded })
            && session.recordingRelativePath == nil
    }

    private func preparedCaptureDecision(for preparation: RecordingPreparation) -> CaptureDecision? {
        let blockerIDs = recordingBlockers(for: preparation)
        let reason = preparation.overrideReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasOverrideReason(reason, for: blockerIDs) else {
            lastStoreError = "Für den Start trotz technischer Warnungen ist eine Begründung erforderlich."
            return nil
        }
        guard recordingIsAllowed(by: preparation.readiness) else {
            lastStoreError = preparation.readiness.summaryDE
            return nil
        }
        var values = CaptureDecision.Values()
        values.blockers = blockerIDs
        values.overrideReason = blockerIDs.isEmpty ? nil : reason
        values.operatorPseudonym = effectiveOperator(from: preparation.operatorPseudonym)
        values.operatingMode = session.operatingMode
        values.operatorAuthenticationMethod = Self.currentOperatorAuthenticationMethod
        return CaptureDecision(values)
    }

    private func hasOverrideReason(_ reason: String, for blockers: [String]) -> Bool {
        blockers.isEmpty || !reason.isEmpty
    }

    private func recordingIsAllowed(by readiness: SessionReadiness) -> Bool {
        readiness.canRecord || readiness.canOverrideQualityWarnings
    }

    private func recordingBlockers(for preparation: RecordingPreparation) -> [String] {
        var blockerIDs = preparation.readiness.blockers.map(\.rawValue)
        let runtimeStatus = preparation.runtimeStatus
        if runtimeStatus.batteryPercent.map({ $0 <= 15 }) == true { blockerIDs.append("batteryLow") }
        if ["ernst", "kritisch"].contains(runtimeStatus.thermalState) {
            blockerIDs.append("thermalState:\(runtimeStatus.thermalState)")
        }
        if !runtimeStatus.spokenAudioCheckCompleted {
            blockerIDs.append("spokenAudioPlaybackCheckMissing")
        }
        return blockerIDs
    }

    private func effectiveOperator(from operatorPseudonym: String) -> String {
        let operatorID = operatorPseudonym.trimmingCharacters(in: .whitespacesAndNewlines)
        return operatorID.isEmpty
            ? session.consentGrants.last(where: { $0.authorizes(.collection) })?.participantGroupPseudonym ?? "local-operator"
            : operatorID
    }

    private func makePreparedRecordingArtifacts(
        for preparation: RecordingPreparation,
        authorization: CaptureAuthorizationSnapshot,
        decision: CaptureDecision,
        preparedAt: Date
    ) async throws -> PreparedRecordingArtifacts {
        try verifyStorageCapacity(for: session.plannedDurationMinutes)
        let frozen = session
        let url = try await asyncStore.prepareRecordingURL(for: frozen)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileWriteFileExists, userInfo: [
                NSLocalizedDescriptionKey: "Der geschützte Aufnahmeplatz ist bereits belegt."
            ])
        }
        let stagedURL = try await asyncStore.prepareStagedRecordingURL(
            for: frozen.id,
            transactionID: preparation.transactionID
        )
        let asset = preparedRecordingAsset(at: url)
        let provenance = Self.captureBuildProvenance(for: frozen.operatingMode)
        let manifest = preparedRecordingManifest(PreparedRecordingManifestInput(
            transactionID: preparation.transactionID,
            session: frozen,
            asset: asset,
            decision: decision,
            provenance: provenance,
            authorization: authorization,
            runtimeStatus: preparation.runtimeStatus
        ))
        return PreparedRecordingArtifacts(
            session: frozen,
            url: url,
            stagedURL: stagedURL,
            asset: asset,
            decision: decision,
            provenance: provenance,
            manifest: manifest,
            preparedAt: preparedAt
        )
    }

    private func preparedRecordingAsset(at url: URL) -> SessionMediaAsset {
        var values = SessionMediaAsset.Values()
        values.role = .ownRecorded
        values.relativePath = url.lastPathComponent
        values.originalFileName = url.lastPathComponent
        return SessionMediaAsset(values)
    }

    private func preparedRecordingManifest(
        _ input: PreparedRecordingManifestInput
    ) -> CaptureTakeManifest {
        var values = CaptureTakeManifest.Values()
        values.id = input.transactionID
        values.sessionID = input.session.id
        values.mediaAssetID = input.asset.id
        values.decision = input.decision
        values.provenance = input.provenance
        values.cameraConfiguration = [
            "negotiated": input.runtimeStatus.videoConfiguration,
            "plannedDurationMinutes": String(input.session.plannedDurationMinutes),
            "batteryPercent": input.runtimeStatus.batteryPercent.map(String.init) ?? "unavailable",
            "thermalState": input.runtimeStatus.thermalState
        ]
        values.audioConfiguration = [
            "route": input.runtimeStatus.audioRoute,
            "spokenAudioPlaybackCheck": input.runtimeStatus.spokenAudioCheckCompleted ? "completed" : "overridden-or-missing"
        ]
        values.deviceDescription = "\(UIDevice.current.model) · \(UIDevice.current.systemName)"
        values.operatingSystemVersion = UIDevice.current.systemVersion
        values.lifecycleState = .prepared
        values.authorization = input.authorization
        return CaptureTakeManifest(values)
    }

    private func persistPreparedRecording(
        _ artifacts: PreparedRecordingArtifacts
    ) async throws -> CaptureSession {
        try await asyncStore.mutateSession(id: artifacts.session.id) { current in
            guard let authorization = artifacts.manifest.authorization,
                  current.authorizes(authorization, at: Date()),
                  !current.mediaAssets.contains(where: { $0.role == .ownRecorded }),
                  current.recordingRelativePath == nil
            else {
                throw CocoaError(.fileWriteNoPermission, userInfo: [
                    NSLocalizedDescriptionKey: "Die vorbereitende Freigabe ist nicht mehr aktiv oder der Aufnahmeplatz ist belegt."
                ])
            }
            current.captureDecisions.append(artifacts.decision)
            current.mediaAssets.append(artifacts.asset)
            current.takeManifests.append(artifacts.manifest)
            current.buildProvenance = artifacts.provenance
            current.updatedAt = max(current.updatedAt, artifacts.preparedAt)
        }
    }

func cancelPreparedRecording(_ prepared: PreparedRecording) async {
    await failPreparedRecording(
        sessionID: prepared.sessionID,
        transactionID: prepared.transactionID,
        stagedURL: prepared.stagedURL,
        reason: "AVFoundation hat den vorbereiteten Start nicht angenommen."
    )
}

func recordingAuthorizationIsValid(_ prepared: PreparedRecording, at date: Date = Date()) -> Bool {
    let target = session.id == prepared.sessionID
        ? session
        : allSessions.first(where: { $0.id == prepared.sessionID })
    return target?.authorizes(prepared.authorization, at: date) ?? false
}

func markRecordingBegan(_ transaction: RecordingTransaction) async {
    do {
        let persisted = try await mutateRecordingTransaction(transaction) { target, index in
            guard target.takeManifests[index].effectiveLifecycleState == .prepared else { return }
            target.takeManifests[index].lifecycleState = .recording
            target.updatedAt = Date()
        }
        if session.id == persisted.id { applyPersistedSession(persisted) }
    } catch {
        lastStoreError = error.localizedDescription
    }
}

func recordingDidFail(_ transaction: RecordingTransaction, reason: String) async {
    await failPreparedRecording(
        sessionID: transaction.sessionID,
        transactionID: transaction.transactionID,
        stagedURL: nil,
        reason: reason
    )
}

}
