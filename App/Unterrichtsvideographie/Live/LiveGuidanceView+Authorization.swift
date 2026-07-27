import SwiftUI

extension LiveGuidanceView {
    func syncOperatingMode() {
        if appSession.session.hasUsableExperimentalProtocol,
           let reference = appSession.session.experimentalProtocol?.protocolIdentifier
        {
            model.operatingMode = .experimentalResearch(protocolReference: reference)
        } else {
            model.operatingMode = .evidenceSafe
        }
    }

    func syncCaptureAuthorization() {
        let authorized: Bool
        let transactionID: UUID?
        if let prepared = activePreparedRecording {
            authorized = appSession.recordingAuthorizationIsValid(prepared)
            transactionID = prepared.transactionID
        } else {
            authorized = appSession.session.authorizes(.collection)
                && appSession.session.authorizes(.localReflection)
            transactionID = nil
        }
        if !authorized {
            audioCheck.cancel(resumeCapture: false)
        }
        model.enforceCaptureAuthorization(authorized, transactionID: transactionID)
    }

    func scheduleAuthorizationDeadline(for prepared: AppSessionModel.PreparedRecording) {
        captureAuthorizationDeadlineTask?.cancel()
        guard let expiry = prepared.authorization.effectiveExpiresAt else { return }
        let stopLeadTime: TimeInterval = 30
        let delay = max(0, expiry.timeIntervalSinceNow - stopLeadTime)
        let nanoseconds = UInt64(min(delay, Double(UInt64.max) / 1_000_000_000) * 1_000_000_000)
        captureAuthorizationDeadlineTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }
            guard activePreparedRecording?.transactionID == prepared.transactionID else { return }
            model.enforceCaptureAuthorization(
                false,
                transactionID: prepared.transactionID,
                reason: "Erforderliche Freigabe läuft in weniger als 30 Sekunden ab - Aufnahme wird finalisiert."
            )
        }
    }

    func formatCapacity(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
