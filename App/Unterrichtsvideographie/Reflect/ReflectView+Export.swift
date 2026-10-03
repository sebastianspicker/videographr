import SessionCore
import SwiftUI
import UIKit

extension ReflectView {
    var metadataReview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                metadataReviewHeader

                export
                if let error = appStore.lastStoreError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(NativeTheme.danger)
                        .accessibilityIdentifier("reflect.exportError")
                }
                exportOutcome
                metadataGrantGuidance
            }
            .padding(12)
            .padding(.bottom, 20)
        }
        .fieldInstrumentDaySurface()
        .toolbar(.visible, for: .navigationBar)
        .accessibilityIdentifier("reflect.metadataReviewScreen")
    }

    private var metadataReviewHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                metadataReviewTitle
                Spacer(minLength: 8)
                metadataReviewStatus
            }
            VStack(alignment: .leading, spacing: 8) {
                metadataReviewTitle
                metadataReviewStatus
            }
        }
    }

    private var metadataReviewTitle: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Metadaten weitergeben")
                .font(.title3.weight(.semibold))
                .foregroundStyle(NativeTheme.dayInk)
            Text("Umfang und Freigaben vor der Systemauswahl prüfen.")
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)
        }
    }

    private var metadataReviewStatus: some View {
        FieldStatusBadge(
            title: appStore.session.canExportExternally ? "Bereit" : "Freigaben prüfen",
            tone: appStore.session.canExportExternally ? .positive : .warning
        )
    }

    @ViewBuilder
    var export: some View {
        FieldPanel(padding: 12) {
            FieldSectionHeader(title: "Paket prüfen", subtitle: appStore.session.title)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    exportContents
                    exportScopes
                }
                VStack(alignment: .leading, spacing: 12) {
                    exportContents
                    exportScopes
                }
            }

            Label("Videodatei nicht enthalten", systemImage: "video.slash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NativeTheme.dayInk)
            Text("Metadaten sind nicht anonym und können Personenbezug haben. Das Paket enthält keine lokale oder importierte Videodatei.")
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)

            if appStore.session.canExportExternally {
                Button {
                    isPreparingExport = true
                    Task {
                        defer { isPreparingExport = false }
                        guard let prepared = await appStore.prepareExportForSharing() else { return }
                        pendingExportOutcome = prepared
                        exportOutcomeCoordinator = ExportOutcomeCoordinator(exportID: prepared.id)
                        preparedExport = prepared
                    }
                } label: {
                    Label(
                        isPreparingExport ? "Paket wird vorbereitet…" : "Paket erstellen und weitergeben",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .buttonStyle(ScientificButtonStyle(prominent: true))
                .disabled(isPreparingExport)
                .accessibilityLabel("Metadatenpaket exportieren")

                Text("Öffnet nach erfolgreicher Vorbereitung die Systemauswahl. Abschluss durch das System ist kein Zustell- oder Lesebeleg.")
                    .font(.caption2)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
            } else {
                Text("Die erforderlichen Freigaben sind nicht aktiv. Sekundärnutzung und externe Weitergabe werden nicht aus der Erhebungsfreigabe abgeleitet.")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
            }
        }
    }

    private var metadataGrantGuidance: some View {
        FieldPanel(padding: 12) {
            Text("Freigaben bleiben sitzungsbezogen")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NativeTheme.dayInk)
            Text("Erhebungsfreigabe erweitert sich nicht automatisch auf Sekundärnutzung oder externe Weitergabe.")
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)
            Button("Freigaben in der Sitzung bearbeiten") {
                onEditSession()
            }
            .buttonStyle(ScientificButtonStyle())
            .accessibilityIdentifier("reflect.editSessionGrants")
        }
    }

    private var exportContents: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Enthalten")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NativeTheme.dayInkSecondary)
            packageLine("Sitzungskontext und Freigabemetadaten")
            packageLine("Menschliche Notizen und Zeitbereiche")
            packageLine("Technische Beobachtungen")
            packageLine("Kodierungsschnappschüsse und Herkunft")
            Text("session.json · annotations.jsonl · observations.jsonl · coding-snapshots.jsonl")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(NativeTheme.dayInkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var exportScopes: some View {
        let required = StudyExportProjection.requiredScopes(for: appStore.session)
        return VStack(alignment: .leading, spacing: 7) {
            Text("Erforderliche Freigaben")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NativeTheme.dayInkSecondary)
            ForEach(ConsentScope.allCases, id: \.self) { scope in
                if required.contains(scope) {
                    FieldScopeChip(title: exportScopeTitle(scope), isOn: appStore.session.authorizes(scope))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    var exportOutcome: some View {
        if let event = appStore.session.exportEvents.max(by: { $0.exportedAt < $1.exportedAt }) {
            let presentation = exportOutcomePresentation(for: event)
            FieldPanel(padding: 12) {
                Label(presentation.title, systemImage: presentation.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(presentation.color)
                Text(presentation.detail)
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkSecondary)
                VStack(alignment: .leading, spacing: 5) {
                    exportOutcomeLine("Paket", "Metadaten ohne Video")
                    exportOutcomeLine("Exportvorgang", event.status.rawValue)
                    exportOutcomeLine("Protokolliert", event.exportedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let failure = event.failureDescription, !failure.isEmpty {
                    Text(failure)
                        .font(.caption2)
                        .foregroundStyle(NativeTheme.danger)
                }
                if event.status == .completed {
                    Text("Externe Kopien können durch die App nicht zurückgerufen werden.")
                        .font(.caption2)
                        .foregroundStyle(NativeTheme.dayInkTertiary)
                }
            }
            .accessibilityIdentifier("reflect.exportOutcome")
        }
    }

    private func exportScopeTitle(_ scope: ConsentScope) -> String {
        switch scope {
        case .collection: return "Erhebung"
        case .localReflection: return "Lokale Reflexion"
        case .researchProcessing: return "Forschungsverarbeitung"
        case .secondaryUse: return "Sekundärnutzung"
        case .externalSharing: return "Externe Weitergabe"
        }
    }

    private func exportOutcomePresentation(for event: ExportEvent) -> (title: String, detail: String, symbol: String, color: Color) {
        switch event.status {
        case .completed:
            return (
                "Weitergabe vom System bestätigt",
                "Das System meldet den Vorgang als abgeschlossen. Dies ist kein Nachweis, dass die Datei zugestellt oder gelesen wurde.",
                "checkmark.circle",
                NativeTheme.accent
            )
        case .attempted:
            return (
                "Weitergabe wird noch eingeordnet",
                "Der vorbereitete Vorgang ist lokal protokolliert. Ein bestätigter Abschluss liegt noch nicht vor.",
                "clock",
                NativeTheme.warning
            )
        case .cancelled:
            return ("Weitergabe abgebrochen", "Die Systemauswahl wurde ohne bestätigten Abschluss beendet.", "xmark.circle", NativeTheme.dayInkTertiary)
        case .failed:
            return ("Weitergabe fehlgeschlagen", "Der Fehler ist im lokalen Exportvorgang vermerkt.", "exclamationmark.triangle", NativeTheme.danger)
        case .outcomeUnknown:
            return ("Ausgang der Weitergabe unbekannt", "Der Vorgang bleibt lokal als ungeklärt protokolliert.", "questionmark.circle", NativeTheme.warning)
        }
    }

    private func exportOutcomeLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(NativeTheme.dayInkSecondary)
                .frame(width: 98, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)
        }
    }

    private func packageLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("·")
                .foregroundStyle(NativeTheme.dayInkTertiary)
            Text(text)
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkSecondary)
        }
    }

    func recordCancelledExportIfNeeded() {
        guard let pending = pendingExportOutcome,
              let coordinator = exportOutcomeCoordinator,
              coordinator.exportID == pending.id
        else { return }
        coordinator.recordDismissal()
        Task { @MainActor in
            await Task.yield()
            guard let outcome = coordinator.dismissalFallbackIfNeeded() else { return }
            submitExportOutcome(outcome, for: pending, coordinator: coordinator)
        }
    }

    func recordActivityExportOutcome(
        _ prepared: AppStore.PreparedExport,
        completed: Bool,
        shareActivityIdentifier: String?,
        failureDescription: String?
    ) {
        guard let coordinator = exportOutcomeCoordinator,
              coordinator.exportID == prepared.id,
              let outcome = coordinator.recordActivityCompletion(
                  completed: completed,
                  shareActivityIdentifier: shareActivityIdentifier,
                  failureDescription: failureDescription
              )
        else { return }
        submitExportOutcome(outcome, for: prepared, coordinator: coordinator)
        preparedExport = nil
    }

    func submitExportOutcome(
        _ outcome: ExportOutcomeCoordinator.Outcome,
        for prepared: AppStore.PreparedExport,
        coordinator: ExportOutcomeCoordinator
    ) {
        Task { @MainActor in
            await appStore.recordExportOutcome(
                prepared,
                completed: outcome.completed,
                shareActivityIdentifier: outcome.shareActivityIdentifier,
                failureDescription: outcome.failureDescription
            )
            guard exportOutcomeCoordinator === coordinator else { return }
            pendingExportOutcome = nil
            exportOutcomeCoordinator = nil
        }
    }
}

struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let completion: @MainActor (Bool, String?, String?) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { activityType, completed, _, error in
            Task { @MainActor in
                completion(completed, activityType?.rawValue, error?.localizedDescription)
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
