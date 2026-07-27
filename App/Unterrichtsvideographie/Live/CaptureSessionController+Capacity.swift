import Foundation

extension CaptureSessionController {
    func startCapacityMonitor(for recording: Recording) {
        stopCapacityMonitor()
        enforceFreeCapacity(for: recording.transaction, stagedURL: recording.temporaryURL)
        guard self.recording?.transaction == recording.transaction,
              self.recording?.finalizing == false
        else { return }
        let monitor = DispatchSource.makeTimerSource(queue: sessionQueue)
        monitor.schedule(deadline: .now() + 10, repeating: 10)
        monitor.setEventHandler { [weak self] in
            self?.enforceFreeCapacity(for: recording.transaction, stagedURL: recording.temporaryURL)
        }
        capacityMonitor = monitor
        monitor.resume()
    }

    func stopCapacityMonitor() {
        capacityMonitor?.setEventHandler {}
        capacityMonitor?.cancel()
        capacityMonitor = nil
    }

    func enforceFreeCapacity(for transaction: RecordingTransaction, stagedURL: URL) {
        guard let recording = activeRecording(for: transaction) else { return }
        guard let available = availableCapacity(for: stagedURL) else {
            emit(.recordingCapacityUpdated(transaction, nil))
            return
        }
        emit(.recordingCapacityUpdated(transaction, available))
        requestStopForLowCapacity(recording, available: available)
    }

    private func requestStopForLowCapacity(_ recording: Recording, available: Int64) {
        guard available < CaptureGuardrails.minimumFreeCapacityBytes else { return }
        var recording = recording
        recording.stopRequested = true
        self.recording = recording
        emit(.recordingStopRequested(
            recording.transaction,
            "Freier Speicher unter Sicherheitsreserve - Aufnahme wird finalisiert."
        ))
        if recording.didStart {
            finishRecordingIfNeeded()
        }
    }

    private func activeRecording(for transaction: RecordingTransaction) -> Recording? {
        guard let recording,
              recording.transaction == transaction,
              !recording.finalizing
        else { return nil }
        return recording
    }

    private func availableCapacity(for stagedURL: URL) -> Int64? {
        let values = try? stagedURL.deletingLastPathComponent().resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        return values?.volumeAvailableCapacityForImportantUsage
    }
}
