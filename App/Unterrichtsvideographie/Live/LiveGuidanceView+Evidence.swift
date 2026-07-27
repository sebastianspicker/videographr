import SwiftUI

extension LiveGuidanceView {
    func liveGuidanceEvidencePane(
        maximumDimensions: Int? = nil,
        prioritizedDimensionID: String? = nil
    ) -> some View {
        var orderedDimensions = model.guidance.observability.dimensions
        if let prioritizedDimensionID,
           let index = orderedDimensions.firstIndex(where: { $0.id == prioritizedDimensionID })
        {
            orderedDimensions.insert(orderedDimensions.remove(at: index), at: 0)
        }
        let dimensions = maximumDimensions.map {
            Array(orderedDimensions.prefix($0))
        } ?? orderedDimensions
        return List {
            if appSession.session.hasUsableExperimentalProtocol {
                Section {
                    Label("Experimenteller Forschungsmodus · nicht validiert", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(NativeTheme.warning)
                    Text("Regelhypothesen sind von Aufnahmesignalen getrennt und beeinflussen weder Bereitschaft noch Reflexionsfragen.")
                        .font(.caption)
                }
                .listRowBackground(NativeTheme.warning.opacity(0.12))
            }

            Section(model.isRecording ? "Direkte Signale während der Aufnahme" : "Direkte Signale vor der Aufnahme") {
                Text(model.isRecording ? "Aufnahme läuft" : (readiness.canRecord ? "Bereit zur Aufnahme" : "Aufnahme prüfen"))
                    .font(.headline)
                    .accessibilityIdentifier("live.recordingState")
                    .accessibilityValue(recordingStateAccessibilityValue)
                ForEach(dimensions) { dimension in
                    HStack(alignment: .top) {
                        Image(systemName: observabilityIcon(dimension.status))
                            .foregroundStyle(observabilityColor(dimension.status))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dimension.labelDE)
                                .accessibilityIdentifier("live.observability.\(dimension.id)")
                            Text(dimension.detailDE)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(observabilityValue(dimension))
                            .font(.caption.monospacedDigit())
                    }
                }
                Text("Diese Werte beschreiben Aufnahmebedingungen, nicht Unterrichtsqualität.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            recordingControls
            liveTips
            audioControls
            deviceAndFormat
            experimentalHypotheses
        }
        .scrollDismissesKeyboard(.immediately)
        .accessibilityIdentifier("live.guidanceList")
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(NativeTheme.nightSurface)
        .tint(NativeTheme.recordAccent)
    }

    private var recordingControls: some View {
        Section("Kontinuierliche Aufnahme") {
            Text(appSession.session.title)
                .font(.headline)
                .accessibilityIdentifier("live.recordingControls")
            Text("Geplant: \(appSession.session.plannedDurationMinutes) Minuten")
                .font(.caption)
                .foregroundStyle(.secondary)
            readinessWarnings
            overrideControls
            auditPseudonym
            recordButtons
            captureRecoveryControls
        }
    }

    @ViewBuilder
    private var readinessWarnings: some View {
        if !readiness.blockers.isEmpty && !model.isRecording {
            ForEach(readiness.blockers) { blocker in
                Label(blocker.messageDE, systemImage: "xmark.octagon")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.warning)
            }
        }
        if model.runtimeStatus.hasResourceWarning && !model.isRecording {
            Label(
                "Geräteressource warnt: Akku \(model.runtimeStatus.batteryPercent.map { "\($0)%" } ?? "-"), Temperatur \(model.runtimeStatus.thermalState)",
                systemImage: "battery.25"
            )
            .font(.caption)
            .foregroundStyle(NativeTheme.warning)
        }
        if !model.runtimeStatus.spokenAudioCheckCompleted && !model.isRecording {
            Label("Sprechprobe wurde noch nicht vollständig abgehört.", systemImage: "ear")
                .font(.caption)
                .foregroundStyle(NativeTheme.warning)
        }
    }

    @ViewBuilder
    private var overrideControls: some View {
        if !model.isRecording && readiness.canOverrideQualityWarnings && requiresOverride {
            Toggle("Trotz technischer Warnungen aufnehmen", isOn: $forceRecord)
                .font(.caption)
                .accessibilityIdentifier("live.forceOverride")
            if forceRecord {
                TextField("Begründung für Override", text: $overrideReason, axis: .vertical)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("live.overrideReason")
            }
        }
    }

    private var auditPseudonym: some View {
        Group {
            TextField("Audit-Pseudonym", text: $operatorPseudonym)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("live.operatorPseudonym")
            Text("Das Pseudonym bezeichnet den Auditkontext; die Geräteauthentifizierung schützt den Zugriff und bestätigt keine reale Identität.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let message = model.recordStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("live.recordStatus")
            }
        }
    }

    private var recordButtons: some View {
        HStack {
            Button { beginRecording() } label: {
                Label(model.isStartingRecording ? "Startet…" : (model.isRecording ? "Läuft…" : "Start"), systemImage: "record.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(NativeTheme.recordAccent)
            .accessibilityIdentifier("live.start")
            .disabled(
                model.isStartingRecording || model.isRecording || model.isFinalizingRecording
                    || audioCheck.blocksCapture
                    || !readiness.canOverrideQualityWarnings || !overrideIsValid
            )

            Button { model.stopRecording() } label: {
                Label("Stop", systemImage: "stop.circle")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("live.stop")
            .disabled((!model.isStartingRecording && !model.isRecording) || model.isFinalizingRecording)
        }
    }

    @ViewBuilder
    private var captureRecoveryControls: some View {
        if let diagnostic = model.artifactRecoveryDiagnostic {
            Text(diagnostic)
                .font(.caption)
                .foregroundStyle(NativeTheme.warning)
                .accessibilityIdentifier("live.artifactRecoveryDiagnostic")
        }
        if model.canRetryCapture {
            Button("Kamera erneut versuchen") { model.retryCapture() }
                .accessibilityIdentifier("live.retry")
        }
        if model.authorizationStatus == .denied || model.authorizationStatus == .restricted
            || model.microphoneAuthorizationStatus == .denied
            || model.microphoneAuthorizationStatus == .restricted
        {
            Button("Berechtigungen in Einstellungen öffnen") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        }
    }

    private var liveTips: some View {
        Section("Live-Hinweise") {
            let tips = filming.visibleTips
            if tips.isEmpty {
                Text(model.isRecording ? "Keine kritischen technischen Hinweise." : "Analysiere Bild, Lage und Audio…")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tips) { PrioritizedTipRow(item: $0, isRecording: model.isRecording) }
            }
        }
    }

    private var audioControls: some View {
        Section("Audio") {
            Text(filming.audio.message)
            Text(filming.audio.actionHint)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            metricRow("Peak", model.audioSample.peakLevel)
            metricRow("Mittel", model.audioSample.averageLevel)
            if let value = model.audioSample.clippingFraction { metricRow("PCM-Vollaussteuerung", value) }
            LabeledContent("Kanäle", value: model.audioSample.channelCount.map(String.init) ?? "nicht verfügbar")
            LabeledContent("Samplerate", value: model.audioSample.sampleRate.map { String(format: "%.0f Hz", $0) } ?? "nicht verfügbar")
            if let value = model.audioSample.baselineLevelEstimate { metricRow("Niedrigstes Fenstermittel", value) }
            LabeledContent("Zeitstempel-Lücke", value: model.audioSample.dropoutDetected ? "erkannt" : "nicht erkannt")
            LabeledContent("Route", value: model.runtimeStatus.audioRoute)
            Text("Der Pegeltest misst Amplitude, PCM-Vollaussteuerung und Zeitstempelkontinuität. Er misst weder True Peak nach ITU-R BS.1770 noch Sprachverständlichkeit. Vor Ort eine Hörprobe durchführen.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            spokenAudioControls
        }
    }

    @ViewBuilder
    private var spokenAudioControls: some View {
        if !model.isRecording && !model.isStartingRecording && !model.isFinalizingRecording {
            Button {
                audioCheck.start(
                    pauseCapture: { model.stop() },
                    resumeCapture: { model.start() },
                    playbackCompleted: { model.markSpokenAudioCheckCompleted() }
                )
            } label: {
                Label("4-Sekunden-Sprechprobe aufnehmen", systemImage: "mic.badge.plus")
            }
            .disabled(
                audioCheck.blocksCapture
                    || !appSession.session.authorizes(.collection)
                    || !appSession.session.authorizes(.localReflection)
            )
            .accessibilityIdentifier("live.audioCheck.record")
            if audioCheck.canPlay {
                Button { audioCheck.play() } label: {
                    Label("Sprechprobe abhören", systemImage: "play.circle")
                }
                .accessibilityIdentifier("live.audioCheck.play")
            }
            if audioCheck.canCancel {
                Button("Sprechprobe abbrechen", role: .cancel) { audioCheck.cancel(resumeCapture: true) }
            }
            Label(audioCheck.statusText, systemImage: audioCheck.statusIcon)
                .font(.caption)
                .foregroundStyle(audioCheck.playbackCompleted ? NativeTheme.positiveNight : NativeTheme.nightInkSecondary)
                .accessibilityIdentifier("live.audioCheck.status")
        }
    }

    private var deviceAndFormat: some View {
        Section("Gerät & Format") {
            LabeledContent("Video", value: model.runtimeStatus.videoConfiguration)
            LabeledContent("Akku", value: model.runtimeStatus.batteryPercent.map { "\($0)%" } ?? "nicht verfügbar")
            LabeledContent("Temperatur", value: model.runtimeStatus.thermalState)
            LabeledContent("Freier Speicher", value: model.runtimeStatus.availableCapacityBytes.map(formatCapacity) ?? "nicht verfügbar")
            Text("Dauer und Dateigröße werden auf die geplante Aufnahme begrenzt; während der Aufnahme wird die Sicherheitsreserve überwacht.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var experimentalHypotheses: some View {
        if appSession.session.hasUsableExperimentalProtocol {
            Section("Experimentelle Regelhypothesen") {
                Text(model.guidance.experimentalHypotheses.limitationDE)
                    .font(.caption)
                    .foregroundStyle(NativeTheme.warning)
                ForEach(model.guidance.experimentalHypotheses.hypotheses.prefix(12)) { hypothesis in
                    LabeledContent(hypothesis.labelDE) {
                        Text(String(format: "Regelaktivierung %.0f %%", hypothesis.ruleSupport * 100))
                            .font(.caption2)
                    }
                }
            }
            .accessibilityIdentifier("live.experimentalHypotheses")
        }
    }
}
