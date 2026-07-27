import AVKit
import Foundation
import SessionCore
import SwiftUI
import UniformTypeIdentifiers

/// Post-take reflection grounded in user-linked media evidence.
/// Field Instrument day-studio layout (non-Form).
struct ReflectView: View {
    @EnvironmentObject var appSession: AppSessionModel

    @State var selectedAssetID: UUID?
    @State var player: AVPlayer?
    @State var rangeStartMilliseconds: Int64?
    @State var playbackMilliseconds: Int64 = 0
    @State var isImportingMedia = false
    @State var preparedExport: AppSessionModel.PreparedExport?
    @State var pendingExportOutcome: AppSessionModel.PreparedExport?
    @State var exportOutcomeCoordinator: ExportOutcomeCoordinator?
    @State var isPreparingExport = false
    @State var focusedPrompt: ReflectionPromptID = .studentLearningEvidence

    var selectedAsset: SessionMediaAsset? {
        let assets = appSession.session.mediaAssets
        guard !assets.isEmpty else { return nil }
        return assets.first(where: { $0.id == selectedAssetID }) ?? assets.first
    }

    var selectedMediaURL: URL? {
        guard let selectedAsset else { return nil }
        return appSession.mediaURL(for: selectedAsset)
    }

    var hasPlayableSelectedMedia: Bool {
        guard let selectedMediaURL else { return false }
        return FileManager.default.fileExists(atPath: selectedMediaURL.path)
    }

    var activeGrantCount: Int {
        appSession.session.consentGrants.filter { $0.withdrawnAt == nil }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProvenanceBar.daySession(appSession.session, activeGrantCount: activeGrantCount)
                GeometryReader { geo in
                    let wide = geo.size.width >= 960
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if wide {
                                HStack(alignment: .top, spacing: 0) {
                                    playerColumn
                                        .frame(maxWidth: .infinity)
                                    lafColumn
                                        .frame(width: min(420, geo.size.width * 0.36))
                                }
                                .background(NativeTheme.daySurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(NativeTheme.dayHairline, lineWidth: 1)
                                }

                                HStack(alignment: .top, spacing: 16) {
                                    notesColumn
                                        .frame(maxWidth: .infinity)
                                    exportColumn
                                        .frame(width: min(320, geo.size.width * 0.28))
                                }
                            } else {
                                playerColumn
                                lafColumn
                                notesColumn
                                exportColumn
                            }
                            experimentalHypotheses
                        }
                        .padding(16)
                        .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .accessibilityIdentifier("reflect.scroll")
                }
            }
            .navigationTitle("Reflektieren")
            .navigationBarTitleDisplayMode(.inline)
            .fieldInstrumentDaySurface()
            .onAppear {
                selectInitialAssetIfNeeded()
                configurePlayer()
            }
            .onChange(of: selectedAssetID) { _, _ in
                rangeStartMilliseconds = nil
                playbackMilliseconds = 0
                configurePlayer()
            }
            .task(id: selectedAssetID) {
                await monitorPlaybackPosition()
            }
            .fileImporter(
                isPresented: $isImportingMedia,
                allowedContentTypes: [.mpeg4Movie],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    guard let url = urls.first else { return }
                    Task { await appSession.importMedia(from: url) }
                case let .failure(error):
                    appSession.lastStoreError = "Video konnte nicht ausgewählt werden: \(error.localizedDescription)"
                }
            }
            .sheet(item: $preparedExport, onDismiss: recordCancelledExportIfNeeded) { prepared in
                SystemShareSheet(items: [prepared.packageURL]) { completed, activityIdentifier, failure in
                    recordActivityExportOutcome(
                        prepared,
                        completed: completed,
                        shareActivityIdentifier: activityIdentifier,
                        failureDescription: failure
                    )
                }
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
        }
    }

    @ViewBuilder
    var sessionContext: some View { reflectSessionContext }
    @ViewBuilder
    var mediaEvidence: some View { reflectMediaEvidence }
    @ViewBuilder
    var playbackControls: some View { reflectPlaybackControls }
    @ViewBuilder
    var experimentalHypotheses: some View { reflectExperimentalHypotheses }
    @ViewBuilder
    var reflectionPrompts: some View { reflectReflectionPrompts }
    @ViewBuilder
    func promptEvidenceControls(for prompt: ReflectionPromptID) -> some View {
        reflectPromptEvidenceControls(for: prompt)
    }
    @ViewBuilder
    func evidenceSummary(for prompt: ReflectionPromptID) -> some View {
        reflectEvidenceSummary(for: prompt)
    }
    @ViewBuilder
    var progress: some View { reflectProgress }
}

#Preview {
    ReflectView().environmentObject(AppSessionModel())
}
