import GuidanceEngine
import SessionCore
import SwiftUI

extension LiveGuidanceView {
    func liveStage(previewHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text("videographr · Sitzung lokal").font(.caption)
                    sessionHeading
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
            }
            if dynamicTypeSize.isAccessibilitySize && previewIsUnavailable {
                accessiblePreviewUnavailableState
            } else {
                previewPane
                    .frame(height: previewHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay { Rectangle().strokeBorder(NativeTheme.nightHairline, lineWidth: 1) }
            }
            signalStrip.padding(.vertical, 14)
            captureDock
            Text("Direkte technische Beobachtungen · Keine Unterrichtsbewertung")
                .font(.caption).foregroundStyle(NativeTheme.nightInkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
        }
        .padding(16)
    }

    var liveToolbar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    exitButton
                    detailsButton
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                standardToolbar
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
        .background(NativeTheme.nightSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(NativeTheme.nightHairline).frame(height: 1)
        }
    }

    private var standardToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) {
                exitButton
                Spacer(minLength: 0)
                sessionHeading
                Spacer(minLength: 0)
                detailsButton
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack { exitButton; Spacer(); detailsButton }
                sessionHeading
            }
        }
    }

    private var exitButton: some View {
        Button(action: onExit) {
            VStack(alignment: .leading, spacing: 4) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("videographr").font(.title3.weight(.medium))
                }
                Label("Sitzung", systemImage: "arrow.left").font(.caption)
            }
            .frame(minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("live.exit")
        .accessibilityLabel("Zur Sitzung")
    }

    private var sessionHeading: some View {
        VStack(spacing: 4) {
            Text(appStore.session.title.isEmpty ? "Neue Sitzung" : appStore.session.title)
                .font(.headline).lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            Text([appStore.session.context.subject,
                  appStore.session.context.gradeLevel.isEmpty ? "" : "Klasse \(appStore.session.context.gradeLevel)"]
                .filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption).foregroundStyle(NativeTheme.nightInkSecondary)
        }
    }

    private var detailsButton: some View {
        Button { inspectorIsVisible.toggle() } label: {
            VStack(alignment: .trailing, spacing: 4) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Label("Lokal", systemImage: "externaldrive").font(.caption)
                }
                Text("Messwerte & Freigaben").font(.subheadline)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("live.inspector.toggle")
    }

    var inspectorPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Messwerte & Details").font(.title2.weight(.medium))
                Spacer()
                Button("Fertig") { inspectorIsVisible = false }
                    .buttonStyle(ScientificButtonStyle())
            }
            .padding(20)
            Divider()
            liveGuidanceEvidencePane(maximumDimensions: 4)
        }
        .fieldInstrumentNightSurface()
    }

    var captureDock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().overlay(NativeTheme.nightHairline)
            if dynamicTypeSize.isAccessibilitySize {
                compactConsole
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 24) {
                        audioMeter.frame(minWidth: 180, maxWidth: .infinity)
                        consoleDivider
                        timingBlock.frame(minWidth: 220, maxWidth: .infinity)
                        consoleDivider
                        recordBlock.frame(minWidth: 230, maxWidth: .infinity)
                    }
                    .frame(minWidth: 760)
                    compactConsole
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var compactConsole: some View {
        VStack(alignment: .leading, spacing: 16) {
            timingBlock
            audioMeter
            recordBlock
        }
    }

    private var consoleDivider: some View {
        Rectangle().fill(NativeTheme.nightHairline).frame(width: 1, height: 100)
    }

    private var audioMeter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TON").font(.caption.weight(.medium))
            LiveAudioMeter(peak: previewIsUnavailable ? 0 : liveStore.audioSample.peakLevel,
                           average: previewIsUnavailable ? 0 : liveStore.audioSample.averageLevel)
                .frame(height: 20)
                .accessibilityLabel("Gemessener Audiopegel")
                .accessibilityValue(audioStatusText)
            Text(liveStore.usingSimulatorFallback || liveStore.privacyCoverIsVisible
                 ? "Audiosignal nicht verfügbar" : filming.audio.message).font(.caption)
                .foregroundStyle(NativeTheme.nightInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Sprachverständlichkeit wird nicht gemessen.")
                .font(.caption).foregroundStyle(NativeTheme.nightInkSecondary)
        }
    }

    private var timingBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            if liveStore.isRecording, let recordingStartedAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(elapsedTimeLabel(from: recordingStartedAt, to: context.date))
                        .font(.system(.largeTitle, design: .monospaced).weight(.medium))
                }
            } else {
                Text("00:00").font(.system(.largeTitle, design: .monospaced).weight(.medium))
            }
            Text("Geplant: \(appStore.session.plannedDurationMinutes) Min.")
                .font(.subheadline).foregroundStyle(NativeTheme.nightInkSecondary)
            Label(appStore.session.canStartNewCapture
                  ? "Erhebung + lokale Reflexion: aktiv"
                  : "Freigaben für Aufnahme fehlen", systemImage: "doc.text")
                .font(.caption)
                .foregroundStyle(appStore.session.canStartNewCapture ? NativeTheme.nightInkSecondary : NativeTheme.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recordBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                liveStore.isRecording ? liveStore.stopRecording() : beginRecording()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: liveStore.isRecording ? "stop.fill" : "circle.fill")
                        .foregroundStyle(liveStore.isRecording ? NativeTheme.nightInk : NativeTheme.recordAccent)
                    Text(recordActionTitle).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(ScientificButtonStyle())
            .background(liveStore.isRecording ? NativeTheme.recordSurface : Color.clear,
                        in: RoundedRectangle(cornerRadius: 4))
            .disabled(liveStore.isStartingRecording || liveStore.isFinalizingRecording
                || (!liveStore.isRecording && (audioCheck.blocksCapture || !readiness.canOverrideQualityWarnings || !overrideIsValid)))
            .accessibilityIdentifier("live.captureDock")
            .accessibilityLabel(liveStore.isRecording ? "Aufnahme stoppen" : "Aufnahme starten")
            Text(recordingStateLabel).font(.caption)
                .accessibilityIdentifier("live.recordingState")
                .accessibilityValue(recordingStateAccessibilityValue)
            if !liveStore.isRecording && !liveStore.runtimeStatus.spokenAudioCheckCompleted {
                Button("Sprechprobe und Startbedingungen prüfen") { inspectorIsVisible = true }
                    .font(.caption).frame(minHeight: 44, alignment: .leading)
            } else {
                Text(liveStore.recordStatusMessage ?? "Freigaben werden beim Start erneut geprüft.")
                    .font(.caption).foregroundStyle(NativeTheme.nightInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var signalStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                directReadout("BILD", id: "currentFrame")
                Spacer(minLength: 0)
                directReadout("LAGE", id: "level")
                Spacer(minLength: 0)
                directReadout("BELICHTUNG", id: "exposure")
            }
            VStack(alignment: .leading, spacing: 10) {
                directReadout("BILD", id: "currentFrame")
                directReadout("LAGE", id: "level")
                directReadout("BELICHTUNG", id: "exposure")
            }
        }
        .accessibilityIdentifier("live.signalStrip")
    }

    private func directReadout(_ title: String, id: String) -> some View {
        let dimension = liveStore.guidance.observability.dimensions.first { $0.id == id }
        let noImage = liveStore.privacyCoverIsVisible || liveStore.usingSimulatorFallback
        let status: CaptureObservabilityDimension.Status = noImage ? .unavailable
            : (dimension?.status ?? (id == "currentFrame" ? .pass : .unavailable))
        let value = status == .unavailable ? "Nicht verfügbar"
            : status == .pass ? (id == "currentFrame" ? "Aktuell" : "Unauffällig")
            : status == .fail ? "Kritisch" : "Prüfen"
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title).font(.caption.weight(.semibold))
            Text(value).font(.caption).foregroundStyle(status == .pass
                ? NativeTheme.nightInkSecondary : observabilityColor(status))
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var recordingStateLabel: String {
        if liveStore.isFinalizingRecording { return "Datei wird geprüft und lokal gesichert." }
        if liveStore.isStartingRecording { return "Aufnahme startet…" }
        if liveStore.isRecording { return "Aufnahme läuft · kontinuierlicher Take" }
        return readiness.canRecord ? "Direkte Startbedingungen erfüllt" : "Aufnahmebedingungen prüfen"
    }

    private var recordActionTitle: String {
        if liveStore.isFinalizingRecording { return "Aufnahme wird gesichert…" }
        if liveStore.isStartingRecording { return "Aufnahme startet…" }
        return liveStore.isRecording ? "Aufnahme beenden" : "Aufnahme starten"
    }

    private func elapsedTimeLabel(from start: Date, to end: Date) -> String {
        let duration = max(0, Int(end.timeIntervalSince(start)))
        return String(format: "%02d:%02d", duration / 60, duration % 60)
    }

    func metricRow(_ title: String, _ value: Double) -> some View {
        LabeledContent(title) {
            Text(String(format: "%.0f %%", value * 100)).monospacedDigit()
        }
    }

    func observabilityIcon(_ status: CaptureObservabilityDimension.Status) -> String {
        switch status {
        case .pass: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.octagon.fill"
        case .unavailable: return "questionmark.circle"
        }
    }

    func observabilityColor(_ status: CaptureObservabilityDimension.Status) -> Color {
        switch status {
        case .pass: return NativeTheme.positiveNight
        case .warn: return NativeTheme.warningNight
        case .fail: return NativeTheme.dangerNight
        case .unavailable: return NativeTheme.nightInkTertiary
        }
    }

    func observabilityValue(_ dimension: CaptureObservabilityDimension) -> String {
        dimension.value.map { String(format: "%.0f %%", $0 * 100) } ?? "-"
    }

    func statusChip(icon: String, text: String, tint: Color = NativeTheme.nightInk) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(2)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(NativeTheme.nightElevated.opacity(0.92), in: RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4).strokeBorder(NativeTheme.nightHairline)
        }
        .foregroundStyle(tint)
    }
}

/// A current amplitude sample, not a calibrated scientific quality scale.
private struct LiveAudioMeter: View {
    let peak: Double
    let average: Double

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<16, id: \.self) { index in
                Rectangle()
                    .fill(Double(index) / 16 < min(1, max(0, max(peak, average)))
                          ? NativeTheme.accent : NativeTheme.nightHairline)
            }
        }
        .accessibilityElement(children: .ignore)
    }
}
