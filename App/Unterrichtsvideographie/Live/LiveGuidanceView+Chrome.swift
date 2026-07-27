import GuidanceEngine
import SwiftUI

extension LiveGuidanceView {
    var liveToolbar: some View {
        HStack(spacing: 18) {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.bordered)
            .clipShape(Circle())
            .accessibilityIdentifier("live.exit")
            .accessibilityLabel("Live-Ansicht verlassen")

            VStack(alignment: .leading, spacing: 3) {
                Text(appSession.session.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text("Live & Aufnahme")
                    .font(.subheadline)
                    .foregroundStyle(NativeTheme.nightInkSecondary)
            }

            Spacer(minLength: 0)

            if filming.criticalCount > 0 {
                Label("\(filming.criticalCount) Hinweis", systemImage: "exclamationmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NativeTheme.warning)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(NativeTheme.warning.opacity(0.12), in: Capsule())
                    .overlay { Capsule().strokeBorder(NativeTheme.warning.opacity(0.35)) }
            }

            Button {
                inspectorIsVisible.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3.weight(.semibold))
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.bordered)
            .clipShape(Circle())
            .accessibilityIdentifier("live.inspector.toggle")
            .accessibilityLabel(inspectorIsVisible ? "Prüfbereich ausblenden" : "Prüfbereich einblenden")
        }
        .padding(.horizontal, 32)
        .background(NativeTheme.nightCanvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NativeTheme.nightHairline)
                .frame(height: 1)
        }
    }

    var inspectorPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    inspectorIsVisible = false
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
                .accessibilityLabel("Prüfbereich schließen")

                Text("Aufnahme prüfen")
                    .font(.title2.weight(.semibold))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .frame(height: 76)

            Rectangle()
                .fill(NativeTheme.nightHairline)
                .frame(height: 1)
            liveGuidanceEvidencePane(maximumDimensions: 4)
        }
        .background(NativeTheme.nightSurface)
    }

    var captureDock: some View {
        NativeTheme.card(role: .night) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.isRecording ? "Aufnahme läuft" : (readiness.canRecord ? "Bereit zur Aufnahme" : "Aufnahme prüfen"))
                        .font(.headline.monospacedDigit())
                        .accessibilityIdentifier("live.recordingState")
                        .accessibilityValue(recordingStateAccessibilityValue)
                    Label(audioStatusText, systemImage: "mic.fill")
                        .font(.caption)
                        .foregroundStyle(NativeTheme.nightInkSecondary)
                }

                Rectangle()
                    .fill(NativeTheme.nightHairline)
                    .frame(width: 1, height: 52)

                Button {
                    model.isRecording ? model.stopRecording() : beginRecording()
                } label: {
                    Image(systemName: model.isRecording ? "stop.fill" : "record.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(model.isRecording ? NativeTheme.nightInk : NativeTheme.recordAccent)
                        .frame(width: 72, height: 72)
                }
                .buttonStyle(.plain)
                .background(
                    model.isRecording ? NativeTheme.danger : NativeTheme.nightElevated,
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .strokeBorder(
                            model.isRecording ? NativeTheme.danger : NativeTheme.recordAccent,
                            lineWidth: 2
                        )
                }
                .accessibilityIdentifier("live.captureDock")
                .accessibilityLabel(model.isRecording ? "Aufnahme stoppen" : "Aufnahme starten")
                .disabled(
                    model.isStartingRecording || model.isFinalizingRecording
                        || (!model.isRecording && (audioCheck.blocksCapture || !readiness.canOverrideQualityWarnings || !overrideIsValid))
                )

                Text(model.isRecording ? "Kontinuierliche\nAufnahme" : "Kontinuierliche\nAufnahme bereit")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NativeTheme.nightInkSecondary)
            }
        }
        .frame(maxWidth: 360)
        .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
        .accessibilityElement(children: .contain)
    }

    func metricRow(_ title: String, _ value: Double) -> some View {
        LabeledContent(title) {
            Text(String(format: "%.0f %%", value * 100)).monospacedDigit()
        }
    }

    var observabilityChip: some View {
        let statuses = model.guidance.observability.dimensions.map(\.status)
        let status: CaptureObservabilityDimension.Status = statuses.contains(.fail)
            ? .fail
            : (statuses.contains(.warn) || statuses.contains(.unavailable) ? .warn : .pass)
        return statusChip(
            icon: observabilityIcon(status),
            text: status == .pass ? "Direkte Signale stabil" : "Aufnahmesignale prüfen",
            tint: observabilityColor(status)
        )
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
        case .warn: return NativeTheme.warning
        case .fail: return NativeTheme.danger
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
        .background(NativeTheme.nightElevated.opacity(0.92), in: Capsule())
        .overlay {
            Capsule().strokeBorder(NativeTheme.nightHairline)
        }
        .foregroundStyle(tint)
    }
}
