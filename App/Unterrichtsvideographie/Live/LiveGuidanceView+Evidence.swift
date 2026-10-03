import SwiftUI
import ExperimentalResearch
import GuidanceEngine

extension LiveGuidanceView {
    func liveGuidanceEvidencePane(
        maximumDimensions: Int? = nil,
        prioritizedDimensionID: String? = nil
    ) -> some View {
        var orderedDimensions = liveStore.guidance.observability.dimensions
        if let prioritizedDimensionID,
           let index = orderedDimensions.firstIndex(where: { $0.id == prioritizedDimensionID })
        {
            orderedDimensions.insert(orderedDimensions.remove(at: index), at: 0)
        }
        let dimensions = maximumDimensions.map {
            Array(orderedDimensions.prefix($0))
        } ?? orderedDimensions
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
            if appStore.session.operatingMode == .experimentalResearch,
               appStore.session.hasUsableExperimentalProtocol
            {
                FieldPanel(role: .night, padding: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                    Label("Experimenteller Forschungsmodus · nicht validiert", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(NativeTheme.warningNight)
                    Text("Regelhypothesen sind von Aufnahmesignalen getrennt und beeinflussen weder Bereitschaft noch Reflexionsfragen.")
                        .font(.caption)
                        .foregroundStyle(NativeTheme.nightInkSecondary)
                    }
                }
                .padding(.bottom, 12)
            }

            instrumentSection(
                liveStore.isRecording ? "Direkte Signale während der Aufnahme" : "Direkte Signale vor der Aufnahme",
                detail: "Direkte Signale"
            ) {
                Text(liveStore.isRecording ? "Aufnahme läuft" : (readiness.canRecord ? "Bereit zur Aufnahme" : "Aufnahme prüfen"))
                    .font(.headline)
                    .accessibilityIdentifier("live.recordingState")
                    .accessibilityValue(recordingStateAccessibilityValue)
                ForEach(dimensions) { dimension in
                    Divider().overlay(NativeTheme.nightHairline)
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: observabilityIcon(dimension.status))
                            .foregroundStyle(observabilityColor(dimension.status))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(dimension.labelDE)
                                Spacer(minLength: 8)
                                Text(observabilityStatusLabel(dimension.status))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(observabilityColor(dimension.status))
                            }
                                .accessibilityIdentifier("live.observability.\(dimension.id)")
                            Text(dimension.detailDE)
                                .font(.caption2)
                                .foregroundStyle(NativeTheme.nightInkSecondary)
                        }
                        Text(observabilityValue(dimension))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(NativeTheme.nightInkSecondary)
                    }
                }
                Text("Diese Werte beschreiben Aufnahmebedingungen, nicht Unterrichtsqualität.")
                    .font(.caption2)
                    .foregroundStyle(NativeTheme.nightInkTertiary)
            }
            recordingControls
            liveTips
            audioControls
            deviceAndFormat
            experimentalHypotheses
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.immediately)
        .accessibilityIdentifier("live.guidanceList")
        .background(NativeTheme.nightSurface)
        .tint(NativeTheme.accent)
    }

    func instrumentSection<Content: View>(
        _ title: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NativeTheme.nightInk)
                Spacer(minLength: 0)
                if let detail {
                    Text(detail)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NativeTheme.nightInkTertiary)
                }
            }
            content()
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NativeTheme.nightHairline)
                .frame(height: 1)
        }
    }

    func observabilityStatusLabel(_ status: CaptureObservabilityDimension.Status) -> String {
        switch status {
        case .pass: "Stabil"
        case .warn: "Prüfen"
        case .fail: "Nicht bereit"
        case .unavailable: "Nicht verfügbar"
        }
    }

    private var recordingControls: some View {
        instrumentSection("Kontinuierliche Aufnahme") {
            Text(appStore.session.title)
                .font(.headline)
                .accessibilityIdentifier("live.recordingControls")
            Text("Geplant: \(appStore.session.plannedDurationMinutes) Minuten")
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
        if !readiness.blockers.isEmpty && !liveStore.isRecording {
            ForEach(readiness.blockers) { blocker in
                Label(blocker.messageDE, systemImage: "xmark.octagon")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.warningNight)
            }
        }
        if liveStore.runtimeStatus.hasResourceWarning && !liveStore.isRecording {
            Label(
                "Geräteressource warnt: Akku \(liveStore.runtimeStatus.batteryPercent.map { "\($0)%" } ?? "-"), Temperatur \(liveStore.runtimeStatus.thermalState)",
                systemImage: "battery.25"
            )
            .font(.caption)
            .foregroundStyle(NativeTheme.warningNight)
        }
        if !liveStore.runtimeStatus.spokenAudioCheckCompleted && !liveStore.isRecording {
            Label("Sprechprobe wurde noch nicht vollständig abgehört.", systemImage: "ear")
                .font(.caption)
                .foregroundStyle(NativeTheme.warningNight)
        }
    }

    @ViewBuilder
    private var overrideControls: some View {
        if !liveStore.isRecording && readiness.canOverrideQualityWarnings && requiresOverride {
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
            if let message = liveStore.recordStatusMessage {
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
                Label(liveStore.isStartingRecording ? "Startet…" : (liveStore.isRecording ? "Läuft…" : "Start"), systemImage: "record.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(NativeTheme.recordSurface)
            .accessibilityIdentifier("live.start")
            .disabled(
                liveStore.isStartingRecording || liveStore.isRecording || liveStore.isFinalizingRecording
                    || audioCheck.blocksCapture
                    || !readiness.canOverrideQualityWarnings || !overrideIsValid
            )

            Button { liveStore.stopRecording() } label: {
                Label("Stop", systemImage: "stop.circle")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("live.stop")
            .disabled((!liveStore.isStartingRecording && !liveStore.isRecording) || liveStore.isFinalizingRecording)
        }
    }

    @ViewBuilder
    private var captureRecoveryControls: some View {
        if let diagnostic = liveStore.artifactRecoveryDiagnostic {
            Text(diagnostic)
                .font(.caption)
                .foregroundStyle(NativeTheme.warningNight)
                .accessibilityIdentifier("live.artifactRecoveryDiagnostic")
        }
        if liveStore.canRetryCapture {
            Button("Kamera erneut versuchen") { liveStore.retryCapture() }
                .accessibilityIdentifier("live.retry")
        }
        if liveStore.authorizationStatus == .denied || liveStore.authorizationStatus == .restricted
            || liveStore.microphoneAuthorizationStatus == .denied
            || liveStore.microphoneAuthorizationStatus == .restricted
        {
            Button("Berechtigungen in Einstellungen öffnen") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        }
    }

    private var liveTips: some View {
        instrumentSection("Live-Hinweise") {
            let tips = filming.visibleTips
            if tips.isEmpty {
                Text(liveStore.isRecording ? "Keine kritischen technischen Hinweise." : "Analysiere Bild, Lage und Audio…")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tips) { PrioritizedTipRow(item: $0, isRecording: liveStore.isRecording) }
            }
        }
    }

    private var audioControls: some View {
        instrumentSection("Audio") {
            Text(filming.audio.message)
            Text(filming.audio.actionHint)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            metricRow("Peak", liveStore.audioSample.peakLevel)
            metricRow("Mittel", liveStore.audioSample.averageLevel)
            if let value = liveStore.audioSample.clippingFraction { metricRow("PCM-Vollaussteuerung", value) }
            LabeledContent("Kanäle", value: liveStore.audioSample.channelCount.map(String.init) ?? "nicht verfügbar")
            LabeledContent("Samplerate", value: liveStore.audioSample.sampleRate.map { String(format: "%.0f Hz", $0) } ?? "nicht verfügbar")
            if let value = liveStore.audioSample.baselineLevelEstimate { metricRow("Niedrigstes Fenstermittel", value) }
            LabeledContent("Zeitstempel-Lücke", value: liveStore.audioSample.dropoutDetected ? "erkannt" : "nicht erkannt")
            LabeledContent("Route", value: liveStore.runtimeStatus.audioRoute)
            Text("Der Pegeltest misst Amplitude, PCM-Vollaussteuerung und Zeitstempelkontinuität. Er misst weder True Peak nach ITU-R BS.1770 noch Sprachverständlichkeit. Vor Ort eine Hörprobe durchführen.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            spokenAudioControls
        }
    }

    @ViewBuilder
    private var spokenAudioControls: some View {
        if !liveStore.isRecording && !liveStore.isStartingRecording && !liveStore.isFinalizingRecording {
            Button {
                audioCheck.start(
                    pauseCapture: { liveStore.stop() },
                    resumeCapture: { liveStore.start() },
                    playbackCompleted: { liveStore.markSpokenAudioCheckCompleted() }
                )
            } label: {
                Label("4-Sekunden-Sprechprobe aufnehmen", systemImage: "mic.badge.plus")
            }
            .disabled(
                audioCheck.blocksCapture
                    || !appStore.session.authorizes(.collection)
                    || !appStore.session.authorizes(.localReflection)
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
        instrumentSection("Gerät & Format") {
            LabeledContent("Video", value: liveStore.runtimeStatus.videoConfiguration)
            LabeledContent("Akku", value: liveStore.runtimeStatus.batteryPercent.map { "\($0)%" } ?? "nicht verfügbar")
            LabeledContent("Temperatur", value: liveStore.runtimeStatus.thermalState)
            LabeledContent("Freier Speicher", value: liveStore.runtimeStatus.availableCapacityBytes.map(formatCapacity) ?? "nicht verfügbar")
            Text("Dauer und Dateigröße werden auf die geplante Aufnahme begrenzt; während der Aufnahme wird die Sicherheitsreserve überwacht.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var experimentalHypotheses: some View {
        if appStore.session.operatingMode == .experimentalResearch,
           appStore.session.hasUsableExperimentalProtocol
        {
            instrumentSection("Experimentelle Regelhypothesen") {
                Text(liveStore.experimentalResult?.hypotheses.limitationDE ?? "Experimentelle Regeln werden erst nach einem aktuellen Aufnahmesignal ausgewertet.")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.warningNight)
                ForEach(liveStore.experimentalResult?.hypotheses.hypotheses.prefix(12) ?? []) { hypothesis in
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
