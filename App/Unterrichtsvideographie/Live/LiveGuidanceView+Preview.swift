import SwiftUI

extension LiveGuidanceView {
    var previewIsUnavailable: Bool {
        liveStore.usingSimulatorFallback || liveStore.privacyCoverIsVisible
    }

    var accessiblePreviewUnavailableState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(previewUnavailableTitle, systemImage: "video.slash")
                .font(.headline)
            Text(previewUnavailableDetail).font(.caption)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
        .accessibilityIdentifier("live.previewUnavailable")
    }
    var previewPane: some View {
        ZStack(alignment: .topLeading) {
            previewImage
            privacyCover
            previewSourceStatus
        }
        .background(Color.black)
    }

    @ViewBuilder private var previewImage: some View {
        if liveStore.usingSimulatorFallback {
            Color.black
            .overlay { simulatorPreviewUnavailableState }
        } else {
            CameraPreviewView(session: liveStore.session)
        }
    }

    /// Simulator values may exercise the direct-signal UI, but never stand in
    /// for a real camera image or recorded take.
    private var simulatorPreviewUnavailableState: some View {
        VStack(spacing: 8) {
            Image(systemName: "video.slash")
                .font(.system(size: 40))
                .foregroundStyle(NativeTheme.nightInk)
            Text("Keine Kameravorschau im Simulator")
                .font(.headline)
                .accessibilityIdentifier("live.preview")
            Text("Simulator")
                .font(.caption2)
                .accessibilityIdentifier("live.captureMode")
                .accessibilityValue("simulator")
            Text(liveStore.lastError ?? "Direkte Bildsignale können hier nur als Testwerte vorliegen.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder private var privacyCover: some View {
        if liveStore.privacyCoverIsVisible {
            Color.black
                .overlay {
                    VStack(spacing: 8) {
                        Label(previewUnavailableTitle, systemImage: "eye.slash.fill")
                            .font(.headline)
                        Text(previewUnavailableDetail)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(NativeTheme.nightInkSecondary)
                            .padding(.horizontal, 28)
                    }
                    .foregroundStyle(.white)
                }
                .accessibilityLabel("Vorschau pausiert, bis ein neues Kamerabild vorliegt")
                .accessibilityIdentifier("live.privacyCover")
        }
    }

    @ViewBuilder private var previewSourceStatus: some View {
        if !previewIsUnavailable && !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(liveStore.isRecording ? "AUFNAHME LÄUFT" : "VORSCHAU")
                        .font(.caption.weight(.semibold))
                    if !liveStore.isRecording {
                        Text("Noch keine Aufnahme").font(.caption)
                    }
                }
                .padding(8).background(Color.black.opacity(0.8))
                Spacer(minLength: 12)
                Text(liveFormatLabel)
                    .font(.caption.monospacedDigit())
                    .padding(8).background(Color.black.opacity(0.8))
            }
            .foregroundStyle(NativeTheme.nightInk)
            .padding(12)
        }
    }

    private var previewUnavailableTitle: String {
        #if targetEnvironment(simulator)
        return "Keine Kameravorschau im Simulator"
        #else
        if liveStore.authorizationStatus == .denied || liveStore.authorizationStatus == .restricted {
            return "Kamerazugriff nicht verfügbar"
        }
        if liveStore.microphoneAuthorizationStatus == .denied || liveStore.microphoneAuthorizationStatus == .restricted {
            return "Mikrofonzugriff nicht verfügbar"
        }
        return "Warte auf ein aktuelles Kamerabild"
        #endif
    }

    private var previewUnavailableDetail: String {
        #if targetEnvironment(simulator)
        return "Eine Aufnahme benötigt ein aktuelles Kamerabild auf einem unterstützten Gerät."
        #else
        if let lastError = liveStore.lastError, !lastError.isEmpty { return lastError }
        if liveStore.authorizationStatus == .denied || liveStore.authorizationStatus == .restricted {
            return "Erlaube den Kamerazugriff in den Einstellungen und versuche die Kamera anschließend erneut."
        }
        if liveStore.microphoneAuthorizationStatus == .denied || liveStore.microphoneAuthorizationStatus == .restricted {
            return "Erlaube den Mikrofonzugriff in den Einstellungen und versuche die Kamera anschließend erneut."
        }
        return "Aufnahme bleibt blockiert, bis ein aktuelles direktes Bildsignal vorliegt."
        #endif
    }

    var audioStatusText: String {
        if liveStore.privacyCoverIsVisible || liveStore.usingSimulatorFallback { return "nicht verfügbar" }
        return switch filming.audio.status {
        case .silent: "stumm"
        case .low: "niedrig"
        case .good: "gut"
        case .hot: "hoch"
        case .clipping: "übersteuert"
        case .dropout: "Aussetzer"
        }
    }

    var recordingStateAccessibilityValue: String {
        if liveStore.isFinalizingRecording { return "finalizing" }
        if liveStore.isStartingRecording { return "starting" }
        return liveStore.isRecording ? "recording" : "idle"
    }

    var evidenceSafeGuidancePane: some View {
        liveGuidanceEvidencePane(maximumDimensions: 4, prioritizedDimensionID: "exposure")
    }
}
