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

    var consentPanel: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            LedgerPair {
                LedgerField("Einwilligungsdokument") {
                    TextField("Dokumentkennung", text: $consentDocumentIdentifier)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .writingLine(mono: true)
                        .accessibilityIdentifier("setup.consent.document")
                        .focused($focusedField, equals: .document).submitLabel(.next)
                }
            } trailing: {
                LedgerField("Version") {
                    TextField("Dokumentversion", text: $consentDocumentVersion)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .writingLine(mono: true)
                        .accessibilityIdentifier("setup.consent.version")
                        .focused($focusedField, equals: .version).submitLabel(.next)
                }
            }
            LedgerPair {
                LedgerField("Gruppenpseudonym") {
                    TextField("Gruppenpseudonym", text: $participantGroupPseudonym)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .writingLine(mono: true)
                        .accessibilityIdentifier("setup.consent.pseudonym")
                        .focused($focusedField, equals: .group).submitLabel(.done)
                }
            } trailing: {
                if let grant = appStore.session.consentGrants.last(where: { $0.withdrawnAt == nil }) {
                    LedgerField("Dokumentiert am") {
                        Text(grant.grantedAt, style: .date)
                            .font(Typeface.value)
                            .foregroundStyle(Ink.instrument)
                            .frame(minHeight: Space.target, alignment: .leading)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                FormLabel("Freigegebene Zwecke")
                    .padding(.bottom, Space.xs)
                ScopeChecklist(scopes: $consentScopes, toggle: consentScopeToggle)
            }

            Toggle("Ablaufdatum festlegen", isOn: $consentExpires)
                .toggleStyle(InkCheckboxStyle())
            if consentExpires {
                DatePicker("Gültig bis", selection: $consentExpiry, in: Date()..., displayedComponents: .date)
                    .font(Typeface.body)
            }

            VStack(alignment: .leading, spacing: Space.s) {
                Button("Freigaben dokumentieren") {
                    appStore.updateConsentGrant(ConsentGrantDraft(
                        scopes: consentScopes,
                        documentIdentifier: consentDocumentIdentifier,
                        documentVersion: consentDocumentVersion,
                        participantGroupPseudonym: participantGroupPseudonym,
                        expiresAt: consentExpires ? consentExpiry : nil
                    ))
                }
                .buttonStyle(InkButtonStyle(kind: .secondary))
                .disabled(!canSaveConsentGrant)
                .accessibilityIdentifier("setup.consent.save")
                if !canSaveConsentGrant {
                    Text("Erforderlich: Dokument, Version, Gruppenpseudonym und mindestens ein Zweck. Ein Ablaufdatum muss in der Zukunft liegen.")
                        .font(Typeface.captionSmall)
                        .foregroundStyle(Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: Space.s) {
                if appStore.session.canStartNewCapture {
                    StatusMark("Erhebung und lokale Reflexion sind dokumentiert.", kind: .secured)
                } else {
                    StatusMark("Für den Aufnahmestart fehlen Freigaben für Erhebung oder lokale Reflexion.", kind: .attention)
                }
                Text("Sekundärnutzung und externe Weitergabe werden beim Export gesondert geprüft. Frühere Bestätigungen ersetzen keine zweckgebundene Freigabe.")
                    .font(Typeface.captionSmall)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var modePanel: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            if appStore.session.operatingMode == .evidenceSafe {
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Text("Evidence-safe").font(Typeface.heading)
                        FormLabel("Standard", small: true)
                    }
                    Text("Die App zeigt direkte Messsignale und fehlende Werte. Sie stellt keine IPN-, TIMSS- oder GTI-Hypothesen als Fakten dar.")
                        .font(Typeface.callout)
                        .foregroundStyle(Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                DisclosureGroup("Experimentellen Modus vorbereiten") {
                    experimentalActivation
                }
                .disclosureGroupStyle(InkDisclosureStyle())
                .accessibilityIdentifier("setup.experimentalActivation")
            } else {
                HypothesisBlock(title: "Experimenteller Forschungsmodus aktiv") {
                    Text("Hypothesen sind nicht validiert. Sie beeinflussen weder die Aufnahmebereitschaft noch ersetzen sie menschliche Kodierung.")
                        .font(Typeface.callout)
                        .foregroundStyle(Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Zum evidenzsicheren Modus zurückkehren") {
                        appStore.returnToEvidenceSafe()
                    }
                    .buttonStyle(InkButtonStyle(kind: .secondary))
                    .accessibilityIdentifier("setup.mode.evidenceSafe")
                }
            }
            Text("experimental · \(appStore.session.operatingMode == .evidenceSafe ? "aus" : "an") · \(appStore.session.experimentalProtocol?.protocolIdentifier ?? "kein Protokoll")")
                .font(Typeface.valueSmall)
                .foregroundStyle(Ink.tertiary)
        }
    }

    private var experimentalActivation: some View {
        HypothesisBlock(title: "Nur für protokollierte Forschung") {
            VStack(alignment: .leading, spacing: Space.l) {
                LedgerPair {
                    LedgerField("Protokoll-ID") {
                        TextField("Protokoll-ID", text: $experimentalProtocolIdentifier)
                            .textInputAutocapitalization(.never)
                            .writingLine(mono: true)
                            .accessibilityIdentifier("setup.experimental.protocol")
                    }
                } trailing: {
                    LedgerField("Aufsicht / Kontakt") {
                        TextField("Aufsicht / Kontakt", text: $experimentalOversightReference)
                            .writingLine()
                            .accessibilityIdentifier("setup.experimental.oversight")
                    }
                }
                DatePicker("Protokoll gültig bis", selection: $experimentalExpiry, in: Date()..., displayedComponents: .date)
                    .font(Typeface.body)
                Toggle("Ich bestätige die sichtbare Kennzeichnung als nicht validiertes Experiment.", isOn: $experimentalDisclosureAcknowledged)
                    .toggleStyle(InkCheckboxStyle())
                    .accessibilityIdentifier("setup.experimental.acknowledged")
                if !appStore.session.authorizes(.researchProcessing) {
                    StatusMark("Zusätzlich erforderlich: eine dokumentierte Freigabe für Forschungsverarbeitung (§ 2).", kind: .attention)
                }
                Button("Experimentellen Modus aktivieren") {
                    appStore.activateExperimentalMode(protocol: ResearchProtocolReference(
                        protocolIdentifier: experimentalProtocolIdentifier,
                        oversightReference: experimentalOversightReference,
                        expiresAt: experimentalExpiry
                    ))
                }
                .buttonStyle(InkButtonStyle(kind: .secondary))
                .disabled(!canActivateExperimentalMode)
                .accessibilityIdentifier("setup.mode.experimental")
            }
        }
    }
}

/// The five consent purposes as ballot boxes, each with what it unlocks.
private struct ScopeChecklist<ToggleView: View>: View {
    @Binding var scopes: Set<ConsentScope>
    let toggle: (ConsentScope, String) -> ToggleView

    private let items: [(scope: ConsentScope, title: String, unlocks: String)] = [
        (.collection, "Aufzeichnung erheben", "nötig für Aufnahme und Export"),
        (.localReflection, "Lokal reflektieren", "nötig für Aufnahme, Videoimport und Notizen"),
        (.researchProcessing, "Für Forschung verarbeiten", "nötig für den experimentellen Modus"),
        (.secondaryUse, "Sekundärnutzung", "nötig für den Metadatenexport"),
        (.externalSharing, "Externes Forschungspaket teilen", "nötig für den Metadatenexport")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items, id: \.scope) { item in
                VStack(alignment: .leading, spacing: 0) {
                    toggle(item.scope, item.title)
                        .accessibilityHint(item.unlocks)
                    Text(item.unlocks)
                        .font(Typeface.captionSmall)
                        .foregroundStyle(Ink.tertiary)
                        .padding(.leading, 32)
                        .padding(.top, -8)
                        .allowsHitTesting(false)
                        .padding(.bottom, Space.s)
                        .accessibilityHidden(true)
                }
                .overlay(alignment: .bottom) { Rule() }
            }
        }
    }
}
