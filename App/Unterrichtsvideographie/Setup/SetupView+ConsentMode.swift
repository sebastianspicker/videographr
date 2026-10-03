import SessionCore
import SwiftUI

extension SetupView {
    var canSaveConsentGrant: Bool {
        !consentScopes.isEmpty
            && !consentDocumentIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !consentDocumentVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !participantGroupPseudonym.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!consentExpires || consentExpiry > Date())
    }

    var scopedConsent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Dokumentierte Freigaben").font(.headline)
            consentPanel
        }
    }

    private var consentPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScientificFormRow(label: "Dokument") {
                TextField("Dokumentkennung", text: $consentDocumentIdentifier)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .scientificInput()
                    .accessibilityIdentifier("setup.consent.document")
                    .focused($focusedField, equals: .document).submitLabel(.next)
            }
            ScientificFormRow(label: "Version") {
                TextField("Dokumentversion", text: $consentDocumentVersion)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .scientificInput()
                    .accessibilityIdentifier("setup.consent.version")
                    .focused($focusedField, equals: .version).submitLabel(.next)
            }
            ScientificFormRow(label: "Gruppenpseudonym") {
                TextField("Gruppenpseudonym", text: $participantGroupPseudonym)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .scientificInput()
                    .accessibilityIdentifier("setup.consent.pseudonym")
                    .focused($focusedField, equals: .group).submitLabel(.done)
            }
            if let grant = appStore.session.consentGrants.last(where: { $0.withdrawnAt == nil }) {
                ScientificFormRow(label: "Erteilt am") {
                    Text(grant.grantedAt, style: .date)
                        .foregroundStyle(NativeTheme.nightInkSecondary)
                }
            }
            FlowScopeToggles(scopes: $consentScopes, toggle: consentScopeToggle)
                .padding(.vertical, 4)
            Toggle("Ablaufdatum festlegen", isOn: $consentExpires)
                .toggleStyle(ScientificCheckboxStyle())
            if consentExpires {
                DatePicker("Gültig bis", selection: $consentExpiry, in: Date()..., displayedComponents: .date)
            }
            Button("Freigaben speichern") {
                appStore.updateConsentGrant(ConsentGrantDraft(
                    scopes: consentScopes,
                    documentIdentifier: consentDocumentIdentifier,
                    documentVersion: consentDocumentVersion,
                    participantGroupPseudonym: participantGroupPseudonym,
                    expiresAt: consentExpires ? consentExpiry : nil
                ))
            }
            .buttonStyle(ScientificButtonStyle())
            .disabled(!canSaveConsentGrant)
            .accessibilityIdentifier("setup.consent.save")
            if !canSaveConsentGrant {
                Text("Dokument, Version, Gruppenpseudonym und mindestens ein Zweck sind erforderlich. Ein Ablaufdatum muss in der Zukunft liegen.")
                    .font(.caption).foregroundStyle(NativeTheme.nightInkSecondary)
            }
            Text(appStore.session.canStartNewCapture
                 ? "Erhebung und lokale Reflexion: aktive Freigaben dokumentiert."
                 : "Für den Aufnahmestart fehlen aktive Freigaben für Erhebung oder lokale Reflexion.")
                .font(.caption)
                .foregroundStyle(appStore.session.canStartNewCapture ? NativeTheme.accent : NativeTheme.warning)
            Text("Sekundärnutzung und externe Weitergabe werden beim Export gesondert geprüft. Frühere Bestätigungen ersetzen keine zweckgebundene Freigabe.")
                .font(.caption).foregroundStyle(NativeTheme.nightInkSecondary)
        }
    }

    var modePanel: some View {
        FieldPanel {
            operatingModeContent
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var operatingModeContent: some View {
        HStack {
            Text("Betriebsmodus")
                .font(.subheadline.weight(.semibold))
            Spacer()
            FieldStatusBadge(
                title: appStore.session.operatingMode == .evidenceSafe ? "Standard" : "Experiment",
                tone: appStore.session.operatingMode == .evidenceSafe ? .positive : .warning
            )
        }

        if appStore.session.operatingMode == .evidenceSafe {
            Text("Evidence-safe")
                .font(.body.weight(.semibold))
                .padding(.top, 10)
            Text("Direkte Messsignale und fehlende Werte. Keine IPN-, TIMSS- oder GTI-Hypothesen als Fakten.")
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)
                .padding(.top, 4)

            Text("Experimenteller Modus: nur für protokollierte Forschung")
                .font(.caption.weight(.semibold))
                .padding(.top, 14)
            TextField("Protokoll-ID", text: $experimentalProtocolIdentifier)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.plain)
                .padding(10)
                .background(NativeTheme.nightElevated, in: RoundedRectangle(cornerRadius: 4))
                .accessibilityIdentifier("setup.experimental.protocol")
            TextField("Aufsicht / Kontakt", text: $experimentalOversightReference)
                .textFieldStyle(.plain)
                .padding(10)
                .background(NativeTheme.nightElevated, in: RoundedRectangle(cornerRadius: 4))
                .accessibilityIdentifier("setup.experimental.oversight")
                .padding(.top, 6)
            DatePicker("Gültig bis", selection: $experimentalExpiry, in: Date()..., displayedComponents: .date)
                .padding(.top, 6)
            Toggle("Ich bestätige die sichtbare Kennzeichnung als nicht validiertes Experiment.", isOn: $experimentalDisclosureAcknowledged)
                .font(.caption)
                .accessibilityIdentifier("setup.experimental.acknowledged")
                .padding(.top, 4)
            if !appStore.session.authorizes(.researchProcessing) {
                Label("Zusätzlich ist ein aktiver Freigabedatensatz für Forschungsverarbeitung erforderlich.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.warning)
                    .padding(.top, 4)
            }
            Button("Experimentellen Modus aktivieren") {
                appStore.activateExperimentalMode(protocol: ResearchProtocolReference(
                    protocolIdentifier: experimentalProtocolIdentifier,
                    oversightReference: experimentalOversightReference,
                    expiresAt: experimentalExpiry
                ))
            }
            .disabled(!canActivateExperimentalMode)
            .accessibilityIdentifier("setup.mode.experimental")
            .padding(.top, 8)
        } else {
            Label("Experimenteller Forschungsmodus aktiv", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(NativeTheme.warning)
                .padding(.top, 10)
            Text("Experimentelle Hypothesen sind nicht validiert, beeinflussen keine Aufnahmebereitschaft und ersetzen keine menschliche Kodierung.")
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)
                .padding(.top, 4)
            Button("Zum evidenzsicheren Modus zurückkehren") {
                appStore.returnToEvidenceSafe()
            }
            .accessibilityIdentifier("setup.mode.evidenceSafe")
            .padding(.top, 8)
        }

        Text("experimental · \(appStore.session.operatingMode == .evidenceSafe ? "aus" : "an") · \(appStore.session.experimentalProtocol?.protocolIdentifier ?? "kein Protokoll")")
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(NativeTheme.dayInkTertiary)
            .padding(.top, 12)
    }
}

/// Layout helper: stack scope toggles with chip-like density while keeping Toggle a11y.
private struct FlowScopeToggles<ToggleView: View>: View {
    @Binding var scopes: Set<ConsentScope>
    let toggle: (ConsentScope, String) -> ToggleView

    private let items: [(ConsentScope, String)] = [
        (.collection, "Aufzeichnung erheben"),
        (.localReflection, "Lokal reflektieren"),
        (.researchProcessing, "Für Forschung verarbeiten"),
        (.secondaryUse, "Sekundärnutzung"),
        (.externalSharing, "Externes Forschungspaket teilen")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.0) { scope, title in
                toggle(scope, title)
                    .font(.subheadline)
            }

        }
    }

}
