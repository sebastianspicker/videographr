@preconcurrency import AVFoundation
import SwiftUI
import GuidanceEngine
import SessionCore

/// Live filming surface: camera preview, readiness, prioritized tips, scene/coding panel, record controls.
///
/// Combines `CameraSessionModel` (sensors + pure `GuidanceEngine`) with `FilmingGuidancePolicy`
/// so continuous classroom takes keep mid-take critical signals without freezing guidance at pre-roll.
struct LiveGuidanceView: View {
    @EnvironmentObject var appSession: AppSessionModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var model = CameraSessionModel()
    @StateObject var audioCheck = SpokenAudioCheckModel()
    /// User override to start recording despite non-critical readiness blockers (research ops).
    @State var forceRecord = false
    @State var overrideReason = ""
    @State var operatorPseudonym = ""
    @State var activePreparedRecording: AppSessionModel.PreparedRecording?
    @State var captureAuthorizationDeadlineTask: Task<Void, Never>?
    @State var inspectorIsVisible = true

    let filmingPolicy = FilmingGuidancePolicy()
    let onExit: () -> Void

    init(onExit: @escaping () -> Void = {}) {
        self.onExit = onExit
    }

    /// Setup + visual + audio gate for the red record button.
    var readiness: SessionReadiness {
        appSession.evaluateReadiness(visual: model.guidance, audio: model.audioSample)
    }

    /// Live pre-roll + mid-take guidance (always re-evaluated from sensors).
    var filming: FilmingGuidanceSnapshot {
        filmingPolicy.evaluate(
            visual: model.guidance,
            audioSample: model.audioSample,
            isRecording: model.isRecording
        )
    }

    var requiresOverride: Bool {
        !readiness.canRecord
            || model.runtimeStatus.hasResourceWarning
            || !model.runtimeStatus.spokenAudioCheckCompleted
    }

    var overrideIsValid: Bool {
        !requiresOverride || (forceRecord && !overrideReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width >= 900
            let inspectorWidth = min(420, max(360, geo.size.width * 0.29))
            let compactPreviewHeight = geo.size.width > geo.size.height
                ? min(geo.size.height * 0.42, 48)
                : min(geo.size.height * 0.42, 180)
            Group {
                if isWide {
                    VStack(spacing: 0) {
                        ProvenanceBar.nightLive(
                            session: appSession.session,
                            isRecording: model.isRecording,
                            formatLabel: liveFormatLabel
                        )
                        liveToolbar
                            .frame(height: 88)

                        HStack(spacing: 0) {
                            previewPane
                                .frame(width: inspectorIsVisible ? geo.size.width - inspectorWidth : geo.size.width)
                            if inspectorIsVisible {
                                inspectorPane
                                    .frame(width: inspectorWidth)
                            }
                        }
                    }
                } else {
                    NavigationStack {
                        VStack(spacing: 0) {
                            ProvenanceBar.nightLive(
                                session: appSession.session,
                                isRecording: model.isRecording,
                                formatLabel: liveFormatLabel
                            )
                            previewPane
                                .frame(height: compactPreviewHeight)
                            if inspectorIsVisible {
                                guidancePane
                                    .frame(maxHeight: .infinity)
                                    .background(NativeTheme.nightSurface)
                            }
                        }
                        .navigationTitle("Live & Aufnahme")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    inspectorIsVisible.toggle()
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                }
                                .accessibilityIdentifier("live.inspector.toggle")
                            }
                        }
                    }
                }
            }
            .fieldInstrumentNightSurface()
            .overlay(alignment: .bottom) {
                if isWide {
                    captureDock
                        .padding(.bottom, 20)
                        .padding(.trailing, inspectorIsVisible ? inspectorWidth : 0)
                }
            }
            // System tab bar is replaced by FieldInstrumentTabBar in RootTabView.
            .toolbar(.hidden, for: .tabBar)
            .onAppear {
                let sessionID = appSession.session.id
                model.bind(to: sessionID)
                model.teachingSituation = appSession.session.teachingSituation
                model.analysisFocus = appSession.session.analysisIntent.codingFocus
                syncOperatingMode()
                operatorPseudonym = appSession.session.consentGrants
                    .last(where: { $0.authorizes(.collection) })?
                    .participantGroupPseudonym ?? ""
                model.onCodingSnapshot = { sessionID, snap in
                    Task {
                        await appSession.attachCodingSnapshot(snap, for: sessionID, recordingIsActive: true)
                    }
                }
                model.onCaptureObservation = { sessionID, observation in
                    Task { await appSession.attachCaptureObservation(observation, for: sessionID) }
                }
                model.onRecordingFinalized = { transaction, url, runtimeStatus in
                    if activePreparedRecording?.transactionID == transaction.transactionID {
                        captureAuthorizationDeadlineTask?.cancel()
                        activePreparedRecording = nil
                    }
                    return await appSession.attachRecording(
                        for: transaction,
                        finalizedURL: url,
                        runtimeStatus: runtimeStatus
                    )
                }
                model.onRecordingBegan = { transaction in
                    Task { await appSession.markRecordingBegan(transaction) }
                }
                model.onRecordingCompletionUnknown = { transaction, _ in
                    if activePreparedRecording?.transactionID == transaction.transactionID {
                        captureAuthorizationDeadlineTask?.cancel()
                        activePreparedRecording = nil
                    }
                    Task { await appSession.recordingCompletionIsUnknown(transaction) }
                }
                model.onRecordingFailed = { transaction, reason in
                    if activePreparedRecording?.transactionID == transaction.transactionID {
                        captureAuthorizationDeadlineTask?.cancel()
                        activePreparedRecording = nil
                    }
                    Task { await appSession.recordingDidFail(transaction, reason: reason) }
                }
                syncCaptureAuthorization()
                model.start()
            }
            .onChange(of: appSession.session.teachingSituation) { _, newValue in
                model.teachingSituation = newValue
            }
            .onChange(of: appSession.session.analysisIntent) { _, newValue in
                model.analysisFocus = newValue.codingFocus
            }
            .onChange(of: appSession.session.operatingMode) { _, _ in
                forceRecord = false
                overrideReason = ""
                syncOperatingMode()
                syncCaptureAuthorization()
            }
            .onChange(of: appSession.session.experimentalProtocol) { _, _ in
                syncOperatingMode()
                syncCaptureAuthorization()
            }
            .onChange(of: appSession.session.consentGrants) { _, _ in
                syncCaptureAuthorization()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    syncOperatingMode()
                    syncCaptureAuthorization()
                } else {
                    audioCheck.cancel(resumeCapture: false)
                }
            }
            .task {
                while !Task.isCancelled {
                    syncOperatingMode()
                    syncCaptureAuthorization()
                    do {
                        try await Task.sleep(nanoseconds: 30_000_000_000)
                    } catch {
                        return
                    }
                }
            }
            .onChange(of: appSession.session.id) { _, newValue in
                forceRecord = false
                overrideReason = ""
                audioCheck.cancel(resumeCapture: false)
                model.bind(to: newValue)
                model.teachingSituation = appSession.session.teachingSituation
                model.analysisFocus = appSession.session.analysisIntent.codingFocus
                syncOperatingMode()
                syncCaptureAuthorization()
                operatorPseudonym = appSession.session.consentGrants
                    .last(where: { $0.authorizes(.collection) })?
                    .participantGroupPseudonym ?? ""
            }
            .onDisappear {
                audioCheck.cancel(resumeCapture: false)
                captureAuthorizationDeadlineTask?.cancel()
                model.stop()
            }
        }
    }

    /// Compact format chip for provenance (falls back when capture is not yet negotiated).
    var liveFormatLabel: String {
        let configuration = model.runtimeStatus.videoConfiguration
        if configuration.isEmpty || configuration == "Noch nicht ausgehandelt" {
            return "1920×1080"
        }
        return configuration
    }
}

#Preview {
    LiveGuidanceView()
        .environmentObject(AppSessionModel())
}
