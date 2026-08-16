import Foundation
import GuidanceEngine
import QuartzCore
import SessionCore

extension CameraSessionModel {
    internal func configureAndStartSession(generation: Int) {
        guard liveIsActive, generation == lifecycleGeneration else { return }
        capture.start(
            generation: generation,
            teachingSituation: teachingSituation,
            rotationAngle: Self.rotationAngle()
        )
    }

    internal func startSimulatorFallback(reason: String, generation: Int) {
        guard liveIsActive, generation == lifecycleGeneration else { return }
#if targetEnvironment(simulator)
        prepareSimulatorFallback(reason: reason)

        #if DEBUG
        // E2E needs one stable fallback snapshot: periodic observable updates otherwise rebuild the
        // List while the test is asserting the simulator recording-rejection state.
        if ProcessInfo.processInfo.environment["VIDEOGRAPHR_E2E_SESSION"] != nil {
            return
        }
        #endif

        scheduleSimulatorUpdates(generation: generation)
#else
        usingSimulatorFallback = false
        isSessionRunning = false
        lastError = reason
        recordStatusMessage = "Kamera/Mikrofon nicht verfügbar. Berechtigungen und Hardware in Einstellungen prüfen."
#endif
    }

#if targetEnvironment(simulator)
    private func prepareSimulatorFallback(reason: String) {
        usingSimulatorFallback = true
        lastError = reason
        isSessionRunning = true
        simulatorTimer?.invalidate()
        simulatorTimer = nil
        simulatorTick = 0
        applySimulatorFrame(FrameAnalyzer.syntheticClassroom())
        cvFeatures = .fixtureClassroomPresent()
        audioSample = makeAudioSample { values in
            values.peakLevel = 0.28
            values.averageLevel = 0.2
            values.externalMicIndicated = true
        }
        requiresFreshLiveSample = false
        if appIsActive, !captureIsInterrupted { privacyCoverIsVisible = false }
        recomputeGuidance()
    }

    private func scheduleSimulatorUpdates(generation: Int) {
        simulatorTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.liveIsActive, self.lifecycleGeneration == generation else { return }
                self.simulatorTick += 1
                self.applySimulatorTick(self.simulatorTick)
            }
        }
    }

    private func applySimulatorTick(_ tick: Int) {
        applySimulatorFrame(simulatorFrame(for: tick % 4))
        cvFeatures = simulatorFeatures(for: tick % 10)
        simAudioPhase = (simAudioPhase + 1) % 3
        audioSample = simulatorAudioSample(for: simAudioPhase)
        recomputeGuidance()
    }

    private func applySimulatorFrame(_ synthetic: (buffer: [Double], width: Int, height: Int)) {
        frameMetrics = FrameAnalyzer().analyze(
            luminance: synthetic.buffer,
            width: synthetic.width,
            height: synthetic.height
        )
    }

    private func simulatorFrame(for phase: Int) -> (buffer: [Double], width: Int, height: Int) {
        var configuration = FrameAnalyzer.SyntheticClassroomConfiguration()
        switch phase {
        case 1:
            configuration.ceilingHeightFraction = 0.48
        case 2:
            configuration.windowSide = .left
            configuration.windowBrightness = 0.99
            configuration.baseLuminance = 0.32
        case 3:
            configuration.boardRect = (0.2, 0.12, 0.6, 0.25)
        default: break
        }
        return FrameAnalyzer.syntheticClassroom(configuration)
    }

    private func simulatorFeatures(for phase: Int) -> CVFeatures {
        let fixtures: [() -> CVFeatures] = [
            CVFeatures.fixtureEmptyRoom,
            CVFeatures.fixturePeopleNoBoard,
            CVFeatures.fixtureBoardNoPeople,
            CVFeatures.fixturePeopleOffZone,
            CVFeatures.fixtureGroupWork,
            CVFeatures.fixtureCircleDiscussion,
            CVFeatures.fixtureExperimentSpread,
            CVFeatures.fixtureSeatworkScattered,
            CVFeatures.fixtureTeacherDemonstration,
            CVFeatures.fixtureClassroomPresent
        ]
        return fixtures[min(max(phase, 0), fixtures.count - 1)]()
    }

    private func simulatorAudioSample(for phase: Int) -> AudioLevelSample {
        switch phase {
        case 0:
            return makeAudioSample { $0.peakLevel = 0.01; $0.averageLevel = 0.005 }
        case 1:
            return makeAudioSample { $0.peakLevel = 0.3; $0.averageLevel = 0.22; $0.externalMicIndicated = true }
        default:
            return makeAudioSample { $0.peakLevel = 0.5; $0.averageLevel = 0.35 }
        }
    }
#endif

    /// Re-run pure guidance + temporal scene/coding windows from the latest sensor samples.
    internal func recomputeGuidance() {
        guard !requiresFreshLiveSample else { return }
        var inputValues = GuidanceInput.Values(
            orientation: motion.orientation,
            frame: frameMetrics
        )
        inputValues.cv = cvFeatures
        inputValues.motion = motion.motionMetrics
        inputValues.teachingSituation = teachingSituation
        inputValues.analysisFocus = analysisFocus
        inputValues.operatingMode = operatingMode
        let input = GuidanceInput(inputValues)
        var result = engine.evaluate(input)

        guard operatingMode.isExperimental else {
            latestCodingSnapshot = nil
            windowedCoding = .empty()
            recentTransitions = []
            persistCaptureObservation(from: result, force: false)
            guidance = result
            return
        }

        // Temporal scene smoothing (stable teaching-scene labels for continuous takes).
        sceneWindow.push(result.scene)
        let smoothedScene = sceneWindow.aggregate() ?? result.scene
        let coding = smoothedCoding(from: result.pedagogicalCoding, scene: smoothedScene)
        windowedCoding = coding
        result = rebuilding(result, scene: smoothedScene, coding: coding)
        observeTransition(in: result)
        updateExperimentalSnapshot(from: result)
        persistCaptureObservation(from: result, force: false)
        guidance = result
    }

    private func rebuilding(
        _ result: GuidanceResult,
        scene: TeachingSceneAssessment,
        coding: PedagogicalCodingResult
    ) -> GuidanceResult {
        let sufficiency = ResearchStructureAssessor.assess(
            cv: cvFeatures,
            scene: scene,
            teachingSituation: teachingSituation
        )
        var values = GuidanceResult.Values(tips: result.tips, placement: result.placement)
        values.scene = scene
        values.pedagogicalCoding = coding
        values.teachingSituation = result.teachingSituation
        var qualityInput = ResearchCaptureQuality.AssessmentInput(
            placement: result.placement,
            scene: scene,
            coding: coding
        )
        qualityInput.teachingSituation = teachingSituation
        qualityInput.structureSufficiency = sufficiency
        values.researchQuality = ResearchCaptureQuality.assess(qualityInput)
        values.structureSufficiency = sufficiency
        values.observability = result.observability
        values.operatingMode = result.operatingMode
        values.experimentalHypotheses = result.experimentalHypotheses
        return GuidanceResult(values)
    }

    private func observeTransition(in result: GuidanceResult) {
        guard transitionDetector.observe(
            scene: result.scene,
            coding: result.pedagogicalCoding
        ) != nil else { return }
        recentTransitions = transitionDetector.events.suffix(8).map { $0 }
    }

    private func updateExperimentalSnapshot(from result: GuidanceResult) {
        let snapshot = ResearchCodingSnapshot.from(
            coding: result.pedagogicalCoding,
            scene: result.scene,
            analysisFocus: analysisFocus,
            provenance: ResearchArtifactProvenance((
                semanticVersion: BuildIdentity.current.semanticVersion,
                buildNumber: BuildIdentity.current.buildNumber,
                schemaVersion: SessionSchema.currentVersion,
                algorithmVersion: "capture-observability-v1+experimental-coding-rules-v1",
                evidenceRegistryVersion: String(EvidenceClaimRegistry.version)
            ))
        )
        latestCodingSnapshot = snapshot
        persistSnapshotIfNeeded(snapshot, result: result)
    }

    private func persistSnapshotIfNeeded(
        _ snapshot: ResearchCodingSnapshot,
        result: GuidanceResult
    ) {
        guard isRecording, !isFinalizingRecording else { return }
        guard !result.experimentalHypotheses.hypotheses.isEmpty else { return }
        let now = CACurrentMediaTime()
        guard now - lastPersistedSnapshotAt >= 5 else { return }
        guard let boundSessionID = activeBoundSessionID() else { return }
        lastPersistedSnapshotAt = now
        onCodingSnapshot?(boundSessionID, snapshot)
    }

    private func activeBoundSessionID() -> UUID? {
        guard let transaction = activeRecordingTransaction else { return nil }
        guard let boundSessionID else { return nil }
        guard boundSessionID == transaction.sessionID else { return nil }
        return boundSessionID
    }

    internal func persistCaptureObservation(
        from result: GuidanceResult,
        force: Bool,
        kind: CaptureObservationKind = .periodic,
        note: String = "Direkte Aufnahmesignale; keine pädagogische Bewertung."
    ) {
        guard let sessionID = captureObservationSessionID(from: result, force: force) else { return }
        guard observationPersistenceIsDue(force: force) else { return }
        let dimensions = result.observability.dimensions
        let unavailable = dimensions.filter { $0.status == .unavailable }.map(\.id)
        var observationValues = CaptureObservation.Values()
        observationValues.kind = kind
        observationValues.measurements = observationMeasurements(from: result)
        observationValues.missingReason = unavailable.isEmpty ? nil : "Nicht verfügbar: \(unavailable.sorted().joined(separator: ", "))"
        observationValues.note = note
        let observation = CaptureObservation(observationValues)
        onCaptureObservation?(sessionID, observation)
    }

    private func captureObservationSessionID(
        from result: GuidanceResult,
        force: Bool
    ) -> UUID? {
        guard force || isRecording else { return nil }
        guard !result.observability.dimensions.isEmpty else { return nil }
        return activeBoundSessionID()
    }

    private func observationPersistenceIsDue(force: Bool) -> Bool {
        let now = CACurrentMediaTime()
        guard force || now - lastPersistedObservationAt >= 5.0 else { return false }
        lastPersistedObservationAt = now
        return true
    }

    private func observationMeasurements(from result: GuidanceResult) -> [String: Double] {
        let dimensions = result.observability.dimensions
        var measurements = Dictionary(uniqueKeysWithValues: dimensions.compactMap { dimension in
            dimension.value.map { (dimension.id, $0) }
        })
        measurements["audioPeak"] = audioSample.peakLevel
        measurements["audioAverage"] = audioSample.averageLevel
        measurements.merge(optionalAudioMeasurements(), uniquingKeysWith: { _, replacement in replacement })
        measurements["audioDropoutDetected"] = audioSample.dropoutDetected ? 1 : 0
        return measurements
    }

    private func optionalAudioMeasurements() -> [String: Double] {
        var measurements: [String: Double] = [:]
        if let value = audioSample.clippingFraction { measurements["audioClippingFraction"] = value }
        if let value = audioSample.channelCount { measurements["audioChannelCount"] = Double(value) }
        if let value = audioSample.sampleRate { measurements["audioSampleRate"] = value }
        if let value = audioSample.baselineLevelEstimate { measurements["audioBaselineEstimate"] = value }
        return measurements
    }
}
