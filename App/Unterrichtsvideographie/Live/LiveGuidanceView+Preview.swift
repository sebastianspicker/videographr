import SwiftUI

extension LiveGuidanceView {
    var previewPane: some View {
        ZStack(alignment: .topLeading) {
            previewImage
            privacyCover
            previewGrid
        }
        .background(Color.black)
    }

    @ViewBuilder private var previewImage: some View {
        if model.usingSimulatorFallback {
            LinearGradient(
                colors: [NativeTheme.elevatedSurface, Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay { simulatorPreview }
        } else {
            CameraPreviewView(session: model.session)
        }
    }

    private var simulatorPreview: some View {
        VStack(spacing: 8) {
            Image(systemName: model.isRecording ? "record.circle" : "video.fill")
                .font(.system(size: 40))
                .foregroundStyle(model.isRecording ? NativeTheme.recordAccent : NativeTheme.nightInk)
            Text(model.isRecording ? "Demo-Aufnahme läuft" : "Demo-Vorschau")
                .font(.headline)
                .accessibilityIdentifier("live.preview")
            Text("Simulator")
                .font(.caption2)
                .accessibilityIdentifier("live.captureMode")
                .accessibilityValue("simulator")
            Text(model.lastError ?? "Synthetisches Klassenzimmer")
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder private var privacyCover: some View {
        if model.privacyCoverIsVisible {
            Color.black
                .overlay {
                    Label("Vorschau pausiert", systemImage: "eye.slash.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Vorschau pausiert, bis ein neues Kamerabild vorliegt")
                .accessibilityIdentifier("live.privacyCover")
        }
    }

    private var previewGrid: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                for fraction in [1.0 / 3.0, 2.0 / 3.0] {
                    path.move(to: CGPoint(x: width * fraction, y: 0))
                    path.addLine(to: CGPoint(x: width * fraction, y: height))
                    path.move(to: CGPoint(x: 0, y: height * fraction))
                    path.addLine(to: CGPoint(x: width, y: height * fraction))
                }
            }
            .stroke(model.isRecording ? NativeTheme.recordAccent.opacity(0.55) : NativeTheme.nightInk.opacity(0.3), lineWidth: model.isRecording ? 2 : 1)
        }
        .allowsHitTesting(false)
    }

    var audioStatusText: String {
        switch filming.audio.status {
        case .silent: "stumm"
        case .low: "niedrig"
        case .good: "gut"
        case .hot: "hoch"
        case .clipping: "übersteuert"
        case .dropout: "Aussetzer"
        }
    }

    var recordingStateAccessibilityValue: String {
        if model.isFinalizingRecording { return "finalizing" }
        if model.isStartingRecording { return "starting" }
        return model.isRecording ? "recording" : "idle"
    }

    var evidenceSafeGuidancePane: some View {
        liveGuidanceEvidencePane(maximumDimensions: 4, prioritizedDimensionID: "exposure")
    }

    var guidancePane: some View { evidenceSafeGuidancePane }
}
