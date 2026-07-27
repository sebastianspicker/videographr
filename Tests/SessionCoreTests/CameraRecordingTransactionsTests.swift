import XCTest
@testable import SessionCore

private func cameraSessionModelSource(_ fileName: String) throws -> String {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceURL = repositoryRoot
        .appendingPathComponent("App/Unterrichtsvideographie/Live", isDirectory: true)
        .appendingPathComponent(fileName)
    return try String(contentsOf: sourceURL, encoding: .utf8)
}

final class CameraRecordingTransactionsTests: XCTestCase {
    func testArtifactOwnershipRollsBackOnlyFailedTransaction() {
        var ownership = RecordingArtifactOwnership<String>()
        let aURL = URL(fileURLWithPath: "/private/tmp/a.mp4")
        let bURL = URL(fileURLWithPath: "/private/tmp/b.mp4")

        XCTAssertTrue(ownership.register("A", at: aURL))
        XCTAssertTrue(ownership.register("B", at: bURL))
        XCTAssertEqual(ownership.validatedDestination(for: "A", matching: aURL), aURL)
        XCTAssertEqual(ownership.confirm("A"), aURL)
        XCTAssertNil(ownership.destination(for: "A"))
        XCTAssertEqual(ownership.destination(for: "B"), bURL)
        XCTAssertEqual(ownership.confirm("B"), bURL)
    }

    func testArtifactOwnershipRejectsOnlyDestinationCollision() {
        var ownership = RecordingArtifactOwnership<String>()
        let destination = URL(fileURLWithPath: "/private/tmp/take.mp4")

        XCTAssertTrue(ownership.register("A", at: destination))
        XCTAssertFalse(ownership.register("B", at: destination))
        XCTAssertTrue(ownership.isDestinationOwned(destination))
        XCTAssertEqual(ownership.destination(for: "A"), destination)
        XCTAssertNil(ownership.destination(for: "B"))
    }

    func testStartWatchdogExpiresWhenDidStartIsDropped() {
        var watchdogs = RecordingTransactionWatchdogs<String>()
        watchdogs.arm(.startAcknowledgement, for: "A")

        XCTAssertTrue(watchdogs.expire(.startAcknowledgement, for: "A"))
        XCTAssertFalse(watchdogs.isArmed(.startAcknowledgement, for: "A"))
    }

    func testFinalizationWatchdogExpiresWhenDidFinishIsDropped() {
        var watchdogs = RecordingTransactionWatchdogs<String>()
        watchdogs.arm(.finalization, for: "A")

        XCTAssertTrue(watchdogs.expire(.finalization, for: "A"))
        XCTAssertFalse(watchdogs.isArmed(.finalization, for: "A"))
    }

    func testStaleWatchdogCannotExpireNewerTransaction() {
        var watchdogs = RecordingTransactionWatchdogs<String>()
        watchdogs.arm(.startAcknowledgement, for: "A")
        watchdogs.arm(.startAcknowledgement, for: "B")

        XCTAssertFalse(watchdogs.expire(.startAcknowledgement, for: "A"))
        XCTAssertTrue(watchdogs.isArmed(.startAcknowledgement, for: "B"))
    }

    func testMatchingTerminalCallbackCancelsOnlyItsWatchdog() {
        var watchdogs = RecordingTransactionWatchdogs<String>()
        watchdogs.arm(.startAcknowledgement, for: "A")
        watchdogs.arm(.finalization, for: "A")
        watchdogs.arm(.metadataAttachment, for: "A")

        XCTAssertTrue(watchdogs.cancel(.startAcknowledgement, for: "A"))
        XCTAssertTrue(watchdogs.cancel(.finalization, for: "A"))
        XCTAssertTrue(watchdogs.cancel(.metadataAttachment, for: "A"))
        XCTAssertFalse(watchdogs.cancel(.finalization, for: "A"))
    }

    func testMetadataTimeoutAllowsLateSuccessToConfirmExactArtifact() {
        var watchdogs = RecordingTransactionWatchdogs<String>()
        var ownership = RecordingArtifactOwnership<String>()
        let url = URL(fileURLWithPath: "/private/tmp/late-success.mp4")
        XCTAssertTrue(ownership.register("A", at: url))
        watchdogs.arm(.metadataAttachment, for: "A")

        XCTAssertTrue(watchdogs.expire(.metadataAttachment, for: "A"))
        XCTAssertEqual(ownership.confirm("A"), url)
        XCTAssertNil(ownership.destination(for: "A"))
    }

    func testMetadataTimeoutAllowsLateFailureToRollbackExactArtifact() {
        var watchdogs = RecordingTransactionWatchdogs<String>()
        var ownership = RecordingArtifactOwnership<String>()
        let url = URL(fileURLWithPath: "/private/tmp/late-failure.mp4")
        XCTAssertTrue(ownership.register("A", at: url))
        watchdogs.arm(.metadataAttachment, for: "A")

        XCTAssertTrue(watchdogs.expire(.metadataAttachment, for: "A"))
        XCTAssertEqual(ownership.validatedDestination(for: "A", matching: url), url)
        XCTAssertEqual(ownership.confirm("A"), url)
    }

    func testStaleMetadataCompletionCannotCancelNewerTransactionWatchdog() {
        var watchdogs = RecordingTransactionWatchdogs<String>()
        watchdogs.arm(.metadataAttachment, for: "A")
        watchdogs.arm(.metadataAttachment, for: "B")

        XCTAssertFalse(watchdogs.cancel(.metadataAttachment, for: "A"))
        XCTAssertTrue(watchdogs.isArmed(.metadataAttachment, for: "B"))
    }

    func testCompletionUnknownStateRoundTripsDurably() throws {
        let encoded = try JSONEncoder().encode(CaptureTakeLifecycleState.completionUnknown)
        XCTAssertEqual(
            try JSONDecoder().decode(CaptureTakeLifecycleState.self, from: encoded),
            .completionUnknown
        )
    }

    func testExpirySourceContractMarksCompletionUnknownAndRejectsStaleTransaction() throws {
        let camera = try cameraSessionModelSource("CameraSessionModel+RecordingRecovery.swift")
        guard let expiryStart = camera.range(of: "func releaseExpiredTransactionUICarrier"),
              let expiryEnd = camera.range(
                  of: "    internal func armStartAcknowledgementWatchdogCarrier",
                  range: expiryStart.lowerBound..<camera.endIndex
              )
        else {
            return XCTFail("Could not locate camera expiry implementation")
        }
        let expiry = String(camera[expiryStart.lowerBound..<expiryEnd.lowerBound])

        XCTAssertTrue(expiry.contains("guard acceptsRecordingEventCarrier(for: transaction) else { return }"))
        XCTAssertTrue(expiry.contains("deferredArtifactTransactions[transaction] = ()"))
        XCTAssertTrue(expiry.contains("onRecordingCompletionUnknown?(transaction, \"Finalisierung wurde nicht bestätigt.\")"))
        XCTAssertFalse(expiry.contains("onRecordingFailed?"))
        XCTAssertTrue(expiry.contains("canRetryCapture = true"))
    }

    func testDeferredFinishedSourceContractAllowsExactLateAttachmentOrRollback() throws {
        let camera = try cameraSessionModelSource("CameraSessionModel+RecordingEvents.swift")
        guard let resolveStart = camera.range(of: "func resolveFinishedRecordingCarrier"),
              let resolveEnd = camera.range(
                  of: "    private func resolveActiveFinishedRecording",
                  range: resolveStart.lowerBound..<camera.endIndex
              )
        else {
            return XCTFail("Could not locate finished-recording resolution")
        }
        let resolution = String(camera[resolveStart.lowerBound..<resolveEnd.lowerBound])
        guard let ownershipCheck = resolution.range(
                  of: "guard acceptsRecordingEventCarrier(for: transaction) || deferredArtifactTransactions[transaction] != nil else { return }"
              ),
              let attachment = resolution.range(of: "await onRecordingFinalized?"),
              let watchdogCancellation = resolution.range(
                  of: "cancelWatchdogCarrier(.metadataAttachment, for: transaction)",
                  range: attachment.lowerBound..<resolution.endIndex
              ),
              let deferredDispatch = resolution.range(of: "resolveDeferredFinishedRecording(")
        else {
            return XCTFail("Missing active/deferred finished-recording branches")
        }

        XCTAssertLessThan(ownershipCheck.lowerBound, attachment.lowerBound)
        XCTAssertLessThan(attachment.lowerBound, watchdogCancellation.lowerBound)
        XCTAssertLessThan(watchdogCancellation.lowerBound, deferredDispatch.lowerBound)
        guard let deferredStart = camera.range(of: "private func resolveDeferredFinishedRecording") else {
            return XCTFail("Could not locate deferred finished-recording resolution")
        }
        let deferred = String(camera[deferredStart.lowerBound...])
        XCTAssertTrue(deferred.contains("guard deferredArtifactTransactions[transaction] != nil else { return }"))
        XCTAssertTrue(deferred.contains("capture.confirmPromotedRecording(for: transaction)"))
        XCTAssertTrue(deferred.contains("capture.rollbackPromotedRecording(url, for: transaction)"))
    }

    func testMetadataWatchdogSourceContractSeparatesDelegateAndAttachmentPhases() throws {
        let camera = try cameraSessionModelSource("CameraSessionModel+RecordingRecovery.swift")

        let events = try cameraSessionModelSource("CameraSessionModel+RecordingEvents.swift")
        XCTAssertTrue(events.contains("if acceptsRecordingEventCarrier(for: transaction) { armMetadataAttachmentWatchdogCarrier(for: transaction) }"))
        XCTAssertTrue(camera.contains("func expireMetadataAttachmentWatchdogCarrier"))
        XCTAssertTrue(camera.contains("recordingWatchdogs.expire(.metadataAttachment, for: transaction)"))
        XCTAssertTrue(camera.contains("releaseExpiredTransactionUICarrier(transaction)"))
    }

    func testDeferredAVFailureSourceContractRemovesOwnershipBeforeTerminalFailure() throws {
        let camera = try cameraSessionModelSource("CameraSessionModel+RecordingEvents.swift")
        guard let failedStart = camera.range(of: "private func handleRecordingFailureEvent"),
              let failedEnd = camera.range(
                  of: "    internal func acceptsRecordingEventCarrier",
                  range: failedStart.lowerBound..<camera.endIndex
              )
        else {
            return XCTFail("Could not locate recording-failure handling")
        }
        let failure = String(camera[failedStart.lowerBound..<failedEnd.lowerBound])
        guard let removal = failure.range(of: "deferredArtifactTransactions.removeValue(forKey: transaction) != nil"),
              let callback = failure.range(of: "onRecordingFailed?(transaction, message)", range: removal.lowerBound..<failure.endIndex)
        else {
            return XCTFail("Deferred AV failure must remove ownership before notifying the owner")
        }
        XCTAssertLessThan(removal.lowerBound, callback.lowerBound)
    }

    func testRecordingStartEmitsBeganBeforeImmediateCapacityEnforcement() throws {
        let controller = try cameraSessionModelSource("CaptureSessionController+Recording.swift")
        guard let didStart = controller.range(of: "didStartRecordingTo"),
              let didFinish = controller.range(
                  of: "didFinishRecordingTo",
                  range: didStart.upperBound..<controller.endIndex
              )
        else {
            return XCTFail("Could not locate recording delegate start implementation")
        }
        let startImplementation = controller[didStart.lowerBound..<didFinish.lowerBound]
        guard let began = startImplementation.range(of: "self.emit(.recordingBegan(recording.transaction))"),
              let capacity = startImplementation.range(of: "self.startCapacityMonitor(for: recording)")
        else {
            return XCTFail("Recording start must emit began and enforce free capacity")
        }

        XCTAssertLessThan(began.lowerBound, capacity.lowerBound)
    }

    func testLateRecordingBeganCannotRegressFinalizingUIState() throws {
        let events = try cameraSessionModelSource("CameraSessionModel+RecordingEvents.swift")
        guard let beganStart = events.range(of: "private func handleRecordingBegan"),
              let beganEnd = events.range(
                  of: "    private func handleRecordingFinalizing",
                  range: beganStart.upperBound..<events.endIndex
              )
        else {
            return XCTFail("Could not locate recording-began state transition")
        }
        let began = String(events[beganStart.lowerBound..<beganEnd.lowerBound])

        XCTAssertTrue(began.contains("stopRequestedDuringStart || isFinalizingRecording"))
        XCTAssertTrue(began.contains("isRecording = !finalizationAlreadyRequested"))
        XCTAssertTrue(began.contains("isFinalizingRecording = finalizationAlreadyRequested"))
    }
}
