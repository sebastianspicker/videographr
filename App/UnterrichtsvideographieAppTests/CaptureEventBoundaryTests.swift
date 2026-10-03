import XCTest
import ExperimentalResearch
import GuidanceEngine
import SessionCore

@testable import Unterrichtsvideographie

final class CaptureEventBoundaryTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UnterrichtsvideographieAppTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    @MainActor
    func testLiveStoreIgnoresStaleGenerationRuntimeEvents() {
        let store = makeLiveStore()
        store.liveIsActive = true
        store.lifecycleGeneration = 42

        store.handleRuntimeEvent(.sessionStarted(41))
        store.handleRuntimeEvent(.configuration(41, videoConfiguration: "stale video", audioRoute: "stale audio"))

        XCTAssertFalse(store.isSessionRunning)
        XCTAssertEqual(store.runtimeStatus.videoConfiguration, "Noch nicht ausgehandelt")
        XCTAssertEqual(store.runtimeStatus.audioRoute, "Keine Audioroute")

        store.handleRuntimeEvent(.sessionStarted(42))
        store.handleRuntimeEvent(.configuration(42, videoConfiguration: "active video", audioRoute: "active audio"))

        XCTAssertTrue(store.isSessionRunning)
        XCTAssertEqual(store.runtimeStatus.videoConfiguration, "active video")
        XCTAssertEqual(store.runtimeStatus.audioRoute, "active audio")
    }

    @MainActor
    func testLiveStoreFiltersCapacityAndStopFactsByExactTransactionIdentity() {
        let store = makeLiveStore()
        let active = transaction(generation: 7)
        let stale = RecordingTransaction(
            sessionID: active.sessionID,
            transactionID: UUID(),
            generation: active.generation
        )
        store.activeRecordingTransaction = active
        store.isRecording = true
        store.runtimeStatus.availableCapacityBytes = 800

        store.handleRuntimeEvent(.recordingCapacityUpdated(stale, 100))
        store.handleTransactionEvent(.recordingStopRequested(stale, "stale stop"))

        XCTAssertEqual(store.runtimeStatus.availableCapacityBytes, 800)
        XCTAssertTrue(store.isRecording)
        XCTAssertFalse(store.isFinalizingRecording)
        XCTAssertNil(store.recordStatusMessage)

        store.handleRuntimeEvent(.recordingCapacityUpdated(active, 200))
        store.handleTransactionEvent(.recordingStopRequested(active, "active stop"))

        XCTAssertEqual(store.runtimeStatus.availableCapacityBytes, 200)
        XCTAssertFalse(store.isRecording)
        XCTAssertTrue(store.isFinalizingRecording)
        XCTAssertEqual(store.recordStatusMessage, "active stop")
    }

    func testDuplicateStopRequestsEmitOneTransactionStopEventWithoutStartingCapture() {
        let controller = CaptureSessionController()
        let transaction = transaction(generation: 11)
        let stagingURL = temporaryDirectory.appendingPathComponent("staging.mov")
        let destinationURL = temporaryDirectory.appendingPathComponent("recording.mov")
        controller.recording = CaptureSessionController.Recording(
            transaction: transaction,
            artifacts: SessionStore(rootDirectory: temporaryDirectory),
            temporaryURL: stagingURL,
            destinationURL: destinationURL,
            didStart: false,
            stopRequested: false,
            finalizing: false
        )

        let stopEvent = expectation(description: "one typed stop request")
        stopEvent.assertForOverFulfill = true
        let sessionQueueDrained = expectation(description: "stop requests drained")
        var receivedStops: [(RecordingTransaction, String)] = []
        controller.transactionEventSink = { event in
            guard case let .recordingStopRequested(receivedTransaction, reason) = event else { return }
            receivedStops.append((receivedTransaction, reason))
            stopEvent.fulfill()
        }

        controller.requestStop(transaction: transaction, reason: "operator request")
        controller.requestStop(transaction: transaction, reason: "duplicate request")
        controller.sessionQueue.async {
            sessionQueueDrained.fulfill()
        }

        wait(for: [stopEvent, sessionQueueDrained], timeout: 1)
        XCTAssertEqual(receivedStops.count, 1)
        XCTAssertEqual(receivedStops.first?.0, transaction)
        XCTAssertEqual(receivedStops.first?.1, "operator request")
        XCTAssertTrue(controller.recording?.stopRequested == true)
        XCTAssertFalse(controller.recording?.didStart == true)
        XCTAssertFalse(controller.recording?.finalizing == true)
    }

    @MainActor
    func testReadinessAndStartRequireACurrentGenerationFrame() {
        let store = makeLiveStore()
        configureReadySession(for: store.appStore)
        store.liveIsActive = true
        store.isSessionRunning = true
        store.lifecycleGeneration = 42
        store.audioSample = readyAudioSample()
        store.invalidateDirectVisualSample()

        let noFrameReadiness = store.appStore.evaluateReadiness(
            visual: store.guidance,
            audio: store.audioSample
        )
        XCTAssertFalse(noFrameReadiness.canRecord)
        XCTAssertEqual(noFrameReadiness.blockers, [.visualSampleMissing])
        XCTAssertFalse(noFrameReadiness.canOverrideQualityWarnings)
        XCTAssertFalse(store.startRecording(recordingStartRequest(for: store, readiness: noFrameReadiness)))
        XCTAssertEqual(store.recordStatusMessage, "Aufnahme blockiert: aktuelles direktes Bildsignal fehlt noch.")

        store.handleRuntimeEvent(.frame(41, directFrameAnalysis()))
        let staleFrameReadiness = store.appStore.evaluateReadiness(
            visual: store.guidance,
            audio: store.audioSample
        )
        XCTAssertFalse(staleFrameReadiness.canRecord)
        XCTAssertEqual(staleFrameReadiness.blockers, [.visualSampleMissing])
        XCTAssertTrue(store.requiresFreshLiveSample)

        store.handleRuntimeEvent(.frame(42, directFrameAnalysis()))
        let currentFrameReadiness = store.appStore.evaluateReadiness(
            visual: store.guidance,
            audio: store.audioSample
        )
        XCTAssertTrue(currentFrameReadiness.canRecord)
        XCTAssertFalse(store.requiresFreshLiveSample)
        XCTAssertTrue(store.startRecording(recordingStartRequest(for: store, readiness: currentFrameReadiness)))
    }

    @MainActor
    func testControllerTransactionSinkDeliversRapidLifecycleFactsInFIFOOrder() {
        let store = makeLiveStore()
        let transaction = transaction(generation: 9)
        store.activeRecordingTransaction = transaction
        store.isStartingRecording = true
        let controller = store.capture
        let finishedURL = temporaryDirectory.appendingPathComponent("finished.mp4")

        let reduced = expectation(description: "transaction events reach the main-actor reducer")
        controller.emitTransaction(.recordingBegan(transaction))
        controller.emitTransaction(.recordingFinalizing(transaction))
        controller.emitTransaction(.recordingFinished(transaction, finishedURL))
        DispatchQueue.main.async { reduced.fulfill() }
        wait(for: [reduced], timeout: 1)

        XCTAssertFalse(store.isStartingRecording)
        XCTAssertFalse(store.isRecording)
        XCTAssertTrue(store.isFinalizingRecording)
        XCTAssertEqual(store.recordStatusMessage, "Aufnahme wird finalisiert…")
    }

    @MainActor
    func testOnlyFreshVisionFramesAdvanceExperimentalWindows() throws {
        let store = makeLiveStore()
        store.liveIsActive = true
        store.lifecycleGeneration = 42
        store.operatingMode = .experimentalResearch

        // Reference session advanced exactly once per fresh frame with the same research results.
        var expected = ExperimentalAnalysisSession()

        store.handleRuntimeEvent(.frame(42, directFrameAnalysis(cvWasRefreshed: true)))
        let firstExperimentalResult = try XCTUnwrap(store.experimentalResult)
        _ = expected.advance(
            with: firstExperimentalResult,
            analysisFocus: store.analysisFocus,
            provenance: BuildProvenanceFactory.researchArtifact
        )
        XCTAssertNotEqual(store.analysis, ExperimentalAnalysisSession())
        XCTAssertEqual(store.analysis, expected)
        let afterFirstFrame = store.analysis

        store.handleRuntimeEvent(.frame(42, directFrameAnalysis(cvWasRefreshed: false)))
        store.recomputeGuidance()
        XCTAssertEqual(store.analysis, afterFirstFrame)
        XCTAssertEqual(store.experimentalResult, firstExperimentalResult)

        store.handleRuntimeEvent(.frame(42, directFrameAnalysis(cvWasRefreshed: true)))
        let secondExperimentalResult = try XCTUnwrap(store.experimentalResult)
        _ = expected.advance(
            with: secondExperimentalResult,
            analysisFocus: store.analysisFocus,
            provenance: BuildProvenanceFactory.researchArtifact
        )
        XCTAssertNotEqual(store.analysis, afterFirstFrame)
        XCTAssertEqual(store.analysis, expected)

        store.teachingSituation = .partnerWork
        XCTAssertEqual(store.analysis, ExperimentalAnalysisSession())
        XCTAssertNil(store.experimentalResult)
    }

    func testMotionGuidanceCadenceBoundsRoutineRefreshesAndPreservesBoundaryChanges() {
        var cadence = MotionGuidanceCadence(minimumInterval: 0.2)
        let acceptable = MotionGuidanceCadence.Boundary(
            orientationIsCritical: false,
            motionIsAcceptable: true
        )
        let critical = MotionGuidanceCadence.Boundary(
            orientationIsCritical: true,
            motionIsAcceptable: true
        )
        let unstable = MotionGuidanceCadence.Boundary(
            orientationIsCritical: true,
            motionIsAcceptable: false
        )

        XCTAssertTrue(cadence.shouldRefresh(at: 10, boundary: acceptable))
        XCTAssertFalse(cadence.shouldRefresh(at: 10.05, boundary: acceptable))
        XCTAssertTrue(cadence.shouldRefresh(at: 10.06, boundary: critical))
        XCTAssertTrue(cadence.shouldRefresh(at: 10.07, boundary: unstable))
        XCTAssertFalse(cadence.shouldRefresh(at: 10.08, boundary: unstable))
        XCTAssertTrue(cadence.shouldRefresh(at: 10.28, boundary: unstable))
    }

    func testVisionFallbackCoverageExcludesResultsFromRicherPreviousRuns() {
        XCTAssertFalse(VisionRequestCoverage.core.includesDocumentsAndText)
        XCTAssertFalse(VisionRequestCoverage.core.includesSaliencyAndPose)
        XCTAssertTrue(VisionRequestCoverage.mid.includesDocumentsAndText)
        XCTAssertFalse(VisionRequestCoverage.mid.includesSaliencyAndPose)
        XCTAssertTrue(VisionRequestCoverage.full.includesDocumentsAndText)
        XCTAssertTrue(VisionRequestCoverage.full.includesSaliencyAndPose)
    }

    func testReusableAudioBufferListGrowsForMoreThanEightNonInterleavedBuffers() {
        let storage = ReusableAudioBufferList(maximumBuffers: 8)
        let initialPointer = storage.pointer
        let required = ReusableAudioBufferList.requiredByteCount(maximumBuffers: 12)

        storage.ensureCapacity(byteCount: required)

        XCTAssertGreaterThanOrEqual(storage.byteCount, required)
        XCTAssertNotEqual(storage.pointer, initialPointer)
        let grownPointer = storage.pointer
        storage.ensureCapacity(byteCount: required - 1)
        XCTAssertEqual(storage.pointer, grownPointer)
    }

    func testThrottledAudioMergeRetainsPeakClippingAndDropoutEvidence() {
        let first = makeAudioSample { values in
            values.peakLevel = 0.92
            values.averageLevel = 0.18
            values.clippingFraction = 0.12
            values.baselineLevelEstimate = 0.08
            values.dropoutDetected = true
        }
        let latest = makeAudioSample { values in
            values.peakLevel = 0.35
            values.averageLevel = 0.24
            values.clippingFraction = 0.01
            values.baselineLevelEstimate = 0.05
        }

        let merged = mergedAudioSample(first, latest)

        XCTAssertEqual(merged.peakLevel, 0.92)
        XCTAssertEqual(merged.averageLevel, 0.24)
        XCTAssertEqual(merged.clippingFraction, 0.12)
        XCTAssertEqual(merged.baselineLevelEstimate, 0.05)
        XCTAssertTrue(merged.dropoutDetected)
    }

    @MainActor
    private func makeLiveStore() -> LiveStore {
        LiveStore(appStore: AppStore(
            store: SessionStore(rootDirectory: temporaryDirectory),
            bootstrapMode: .deferred
        ))
    }

    private func transaction(generation: Int) -> RecordingTransaction {
        RecordingTransaction(sessionID: UUID(), transactionID: UUID(), generation: generation)
    }

    @MainActor
    private func configureReadySession(for appStore: AppStore) {
        var contextValues = SessionContext.Values()
        contextValues.subject = "Mathematik"
        contextValues.lessonGoal = "Brueche vergleichen"
        var grantValues = ConsentGrant.Values()
        grantValues.scopes = [.collection, .localReflection]
        grantValues.documentIdentifier = "local-test"
        grantValues.documentVersion = "1"
        grantValues.participantGroupPseudonym = "test-group"
        grantValues.expiresAt = Date().addingTimeInterval(3_600)
        var sessionValues = CaptureSession.Values()
        sessionValues.context = SessionContext(contextValues)
        sessionValues.consentGrants = [ConsentGrant(grantValues)]
        appStore.replaceSession(CaptureSession(sessionValues))
    }

    private func readyAudioSample() -> AudioLevelSample {
        AudioLevelSample({
            var values = AudioLevelSample.Values()
            values.peakLevel = 0.25
            values.averageLevel = 0.2
            return values
        }())
    }

    private func directFrameAnalysis(cvWasRefreshed: Bool = true) -> LiveFrameAnalysis {
        LiveFrameAnalysis(
            metrics: FrameAnalyzer().analyze(luminance: Array(repeating: 0.5, count: 16), width: 4, height: 4),
            cv: .fixtureClassroomPresent(),
            cvWasRefreshed: cvWasRefreshed
        )
    }

    @MainActor
    private func recordingStartRequest(for store: LiveStore, readiness: SessionReadiness) -> RecordingStartRequest {
        RecordingStartRequest(
            url: temporaryDirectory.appendingPathComponent("recording.mp4"),
            stagedURL: temporaryDirectory.appendingPathComponent("recording.staging.mp4"),
            allowDespiteWarnings: false,
            readiness: readiness,
            plannedDurationMinutes: 45,
            sessionID: store.appStore.session.id,
            transactionID: UUID(),
            artifacts: store.appStore.recordingArtifacts
        )
    }
}
