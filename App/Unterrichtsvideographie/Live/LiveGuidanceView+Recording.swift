import SwiftUI
import SessionCore

extension LiveGuidanceView {
    @MainActor
    func beginRecording() {
        Task {
            guard !rejectSimulatorRecordingIfNeeded() else { return }
            guard let prepared = await prepareRecording() else { return }
            guard await validateAuthorization(for: prepared) else { return }
            await startPreparedRecording(prepared)
        }
    }

    private func rejectSimulatorRecordingIfNeeded() -> Bool {
        guard model.usingSimulatorFallback else { return false }
        model.rejectSimulatorRecordingAttempt()
        return true
    }

    private func prepareRecording() async -> AppSessionModel.PreparedRecording? {
        let transactionID = UUID()
        let preparation = AppSessionModel.RecordingPreparation(
            transactionID: transactionID,
            readiness: readiness,
            overrideReason: forceRecord ? overrideReason : "",
            operatorPseudonym: operatorPseudonym,
            runtimeStatus: model.runtimeStatus
        )
        guard let prepared = await appSession.prepareSessionForRecording(preparation) else {
            model.showRecordingPreparationError(
                appSession.lastStoreError ?? "Die Sitzung konnte nicht für die Aufnahme vorbereitet werden."
            )
            return nil
        }
        return prepared
    }

    private func validateAuthorization(for prepared: AppSessionModel.PreparedRecording) async -> Bool {
        guard appSession.recordingAuthorizationIsValid(prepared) else {
            await appSession.cancelPreparedRecording(prepared)
            model.showRecordingPreparationError(
                "Aufnahme blockiert: die vorbereitende Freigabe ist nicht mehr aktiv."
            )
            syncCaptureAuthorization()
            return false
        }
        return true
    }

    private func startPreparedRecording(_ prepared: AppSessionModel.PreparedRecording) async {
        let started = model.startRecording(RecordingStartRequest(
            url: prepared.url,
            stagedURL: prepared.stagedURL,
            allowDespiteWarnings: requiresOverride && forceRecord,
            readiness: readiness,
            plannedDurationMinutes: prepared.plannedDurationMinutes,
            sessionID: prepared.sessionID,
            transactionID: prepared.transactionID,
            store: appSession.store
        ))
        guard started else {
            await appSession.cancelPreparedRecording(prepared)
            return
        }
        activePreparedRecording = prepared
        syncCaptureAuthorization()
        scheduleAuthorizationDeadline(for: prepared)
        forceRecord = false
        overrideReason = ""
    }
}
