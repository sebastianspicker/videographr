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

    @ViewBuilder
    var scopedConsent: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldSectionHeader(
                title: "Freigaben & Betriebsmodus",
                subtitle: "nur v2-Grants autorisieren Aufnahme und Export"
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    consentPanel
                    modePanel
                }
                VStack(alignment: .leading, spacing: 12) {
                    consentPanel
                    modePanel
                }
            }
        }
    }

    @ViewBuilder
    var operatingMode: some View {
        EmptyView()
    }

    private var consentPanel: some View {
        FieldPanel {
            HStack {
                Text("Aktive Scopes")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                FieldStatusBadge(
                    title: activeGrantCount > 0 ? "Gültig" : "Offen",
                    tone: activeGrantCount > 0 ? .positive : .warning
                )
            }
            Text("Frühere Bestätigungen bleiben als Altbestand sichtbar, autorisieren aber keine neue Aufnahme oder Weitergabe.")
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Dokumentkennung", text: $consentDocumentIdentifier)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(NativeTheme.dayCanvas, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("setup.consent.document")
                TextField("Dokumentversion", text: $consentDocumentVersion)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(NativeTheme.dayCanvas, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("setup.consent.version")
                TextField("Gruppenpseudonym", text: $participantGroupPseudonym)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(NativeTheme.dayCanvas, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("setup.consent.pseudonym")
            }
            .padding(.top, 10)

            FlowScopeToggles(
                scopes: $consentScopes,
                toggle: consentScopeToggle
            )
            .padding(.top, 12)

            Text("Sekundärnutzung und externe Freigabe werden für jedes Forschungspaket getrennt geprüft.")
                .font(.caption)
                .foregroundStyle(NativeTheme.dayInkTertiary)
                .padding(.top, 8)

            Toggle("Ablaufdatum festlegen", isOn: $consentExpires)
                .padding(.top, 8)
            if consentExpires {
                DatePicker("Gültig bis", selection: $consentExpiry, in: Date()..., displayedComponents: .date)
            }

            Button("Einwilligung speichern") {
                appSession.updateConsentGrant(AppSessionModel.ConsentGrantDraft(
                    scopes: consentScopes,
                    documentIdentifier: consentDocumentIdentifier,
                    documentVersion: consentDocumentVersion,
                    participantGroupPseudonym: participantGroupPseudonym,
                    expiresAt: consentExpires ? consentExpiry : nil
                ))
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSaveConsentGrant)
            .accessibilityIdentifier("setup.consent.save")
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var modePanel: some View {
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
                title: appSession.session.operatingMode == .evidenceSafe ? "Standard" : "Experiment",
                tone: appSession.session.operatingMode == .evidenceSafe ? .positive : .warning
            )
        }

        if appSession.session.operatingMode == .evidenceSafe {
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
                .background(NativeTheme.dayCanvas, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityIdentifier("setup.experimental.protocol")
            TextField("Aufsicht / Kontakt", text: $experimentalOversightReference)
                .textFieldStyle(.plain)
                .padding(10)
                .background(NativeTheme.dayCanvas, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityIdentifier("setup.experimental.oversight")
                .padding(.top, 6)
            DatePicker("Gültig bis", selection: $experimentalExpiry, in: Date()..., displayedComponents: .date)
                .padding(.top, 6)
            Toggle("Ich bestätige die sichtbare Kennzeichnung als nicht validiertes Experiment.", isOn: $experimentalDisclosureAcknowledged)
                .font(.caption)
                .accessibilityIdentifier("setup.experimental.acknowledged")
                .padding(.top, 4)
            if !appSession.session.authorizes(.researchProcessing) {
                Label("Zusätzlich ist ein aktiver Freigabedatensatz für Forschungsverarbeitung erforderlich.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.warning)
                    .padding(.top, 4)
            }
            Button("Experimentellen Modus aktivieren") {
                appSession.session.experimentalProtocol = ResearchProtocolReference(
                    protocolIdentifier: experimentalProtocolIdentifier,
                    oversightReference: experimentalOversightReference,
                    expiresAt: experimentalExpiry
                )
                appSession.session.operatingMode = .experimentalResearch
                appSession.markDirty()
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
                appSession.session.operatingMode = .evidenceSafe
                appSession.session.experimentalProtocol = nil
                appSession.markDirty()
            }
            .accessibilityIdentifier("setup.mode.evidenceSafe")
            .padding(.top, 8)
        }

        Text("experimental · \(appSession.session.operatingMode == .evidenceSafe ? "aus" : "an") · \(appSession.session.experimentalProtocol?.protocolIdentifier ?? "kein Protokoll")")
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
            HStack(spacing: 6) {
                ForEach(items, id: \.0) { scope, title in
                    FieldScopeChip(title: shortLabel(scope), isOn: scopes.contains(scope))
                }
            }
            .padding(.top, 4)
            .accessibilityHidden(true)
        }
    }

    private func shortLabel(_ scope: ConsentScope) -> String {
        switch scope {
        case .collection: return "Erhebung"
        case .localReflection: return "Lokale Reflexion"
        case .researchProcessing: return "Forschung"
        case .secondaryUse: return "Sekundärnutzung"
        case .externalSharing: return "Externer Export"
        }
    }
}
