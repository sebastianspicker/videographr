import SessionCore
import SwiftUI
import UIKit

extension ReflectView {
    @ViewBuilder
    var export: some View {
        FieldPanel {
            Text("Study package v3")
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 4) {
                packageLine("session.json + manifest")
                packageLine("Media digests (SHA-256)")
                packageLine("Consent freeze snapshot")
                packageLine("Build provenance")
            }
            .padding(.top, 6)

            Text("sha256 · membership exact · no video payload")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(NativeTheme.dayInkTertiary)
                .padding(.top, 8)

            if appSession.session.canExportExternally {
                Button {
                    isPreparingExport = true
                    Task {
                        defer { isPreparingExport = false }
                        guard let prepared = await appSession.prepareExportForSharing() else { return }
                        pendingExportOutcome = prepared
                        exportOutcomeCoordinator = ExportOutcomeCoordinator(exportID: prepared.id)
                        preparedExport = prepared
                    }
                } label: {
                    Text(isPreparingExport ? "Paket wird vorbereitet…" : "Paket vorbereiten")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(NativeTheme.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .disabled(isPreparingExport)
                .accessibilityLabel("Metadatenpaket exportieren")
                .padding(.top, 12)

                Text("Das Paket enthält Sitzungsmetadaten, Beobachtungen und Annotationen, aber keine Videodateien. Sekundärnutzung und externe Freigabe müssen aktiv sein.")
                    .font(.caption2)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
                    .padding(.top, 8)
            } else {
                Text("Export erfordert aktive Scopes für Sekundärnutzung und externe Weitergabe.")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
                    .padding(.top, 8)
            }
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
        _ prepared: AppSessionModel.PreparedExport,
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
        for prepared: AppSessionModel.PreparedExport,
        coordinator: ExportOutcomeCoordinator
    ) {
        Task { @MainActor in
            await appSession.recordExportOutcome(
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
