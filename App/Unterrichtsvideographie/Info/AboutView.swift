import GuidanceEngine
import SwiftUI

/// In-app product identity, epistemic boundary, and technical footprint.
struct AboutView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProvenanceBar(
                    role: .day,
                    segments: ["Evidence-safe", "Alpha", "Nur lokal"],
                    trailing: BuildIdentity.current.displayVersion
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        FieldViewHeader(
                            eyebrow: "05 · Wissenschaftliche Alpha",
                            title: "Über Videographr",
                            summary: "Lokale Software für kontinuierliche Videoaufnahme und evidenzverknüpfte Reflexion in der Lehrkräftebildung."
                        ) {
                            FieldStatusBadge(title: "Alpha", tone: .neutral)
                        }

                        FieldPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                FieldSectionHeader(title: "Videographr")
                                factRow("Produkt", "Videographr")
                                factRow("Version", BuildIdentity.current.displayVersion, monospaced: true)
                                factRow("Domäne", "Unterrichtsvideographie")
                                Text("Lokale Alpha-Software für kontinuierliche Videoaufnahme und evidenzverknüpfte Reflexion in der Lehrkräftebildung. Kein validiertes Kodierinstrument, kein Wirksamkeitsnachweis und kein Video-Portal.")
                                    .font(.footnote)
                                    .foregroundStyle(NativeTheme.dayInkSecondary)
                                    .accessibilityIdentifier("info.content")
                            }
                        }

                        FieldPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                FieldSectionHeader(title: "Normalbetrieb: evidenzsicher")
                                Label("Direkte technische Beobachtbarkeit", systemImage: "eye")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(NativeTheme.dayInk)
                                Text("Setup mit zweckgebundener Einwilligung → technische Aufnahmehinweise zu Horizont, Kameraruhe, Belichtung, sichtbaren Bildstrukturen und Audiopegel → Reflexion mit selbst gesetzten Zeitmarken.")
                                    .font(.body)
                                    .foregroundStyle(NativeTheme.dayInkSecondary)
                                Text("Bildstruktur-Signale beschreiben nur Beobachtbarkeit. Sie erkennen weder Unterrichtsqualität noch Lernen, Aufmerksamkeit, Feedback oder Beteiligung.")
                                    .font(.caption)
                                    .foregroundStyle(NativeTheme.dayInkTertiary)
                            }
                        }

                        FieldPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                FieldSectionHeader(title: "Experimenteller Modus")
                                Label("Unvalidierte regelbasierte Hypothesen", systemImage: "exclamationmark.triangle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(NativeTheme.warning)
                                Text("Nur nach Eingabe einer gültigen Protokoll- und Aufsichtsreferenz. Regelaktivierungen werden dauerhaft getrennt vom Normalbetrieb gekennzeichnet und dürfen nicht als Wahrscheinlichkeit, menschlicher Code oder pädagogische Bewertung interpretiert werden.")
                                    .font(.caption)
                                    .foregroundStyle(NativeTheme.dayInkSecondary)
                            }
                        }

                        FieldPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                FieldSectionHeader(title: "Technischer Datenweg")
                                Text("CoreMotion und AVCapture → lokale Signalextraktion → technische Aufnahmehinweise → lokaler SessionStore. Video, Metadaten und Reflexion bleiben ohne ausdrückliche Freigabe im App-Speicher.")
                                    .font(.footnote)
                                    .foregroundStyle(NativeTheme.dayInkSecondary)
                                Label("Der lokale Zugriff ist durch die iOS-Geräteeigentümer-Authentifizierung geschützt. Ein Audit-Pseudonym ist keine bestätigte Identität.", systemImage: "lock")
                                    .font(.caption)
                                    .foregroundStyle(NativeTheme.dayInkTertiary)
                            }
                        }

                        FieldPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                FieldSectionHeader(title: "Nachweisstand")
                                factRow("Claim-Register", "v\(EvidenceClaimRegistry.version)")
                                Text(EvidenceClaimRegistry.claims.first?.allowedWordingDE ?? "Die App meldet direkt beobachtbare Aufnahmebedingungen.")
                                    .font(.footnote)
                                    .foregroundStyle(NativeTheme.dayInkSecondary)
                                Text("Der aktuelle Stand belegt Implementierung und automatisierte Tests. Geräte-, Human-Rater- und Wirksamkeitsvalidierung sind getrennte, noch nicht erfüllte Stufen.")
                                    .font(.caption)
                                    .foregroundStyle(NativeTheme.dayInkTertiary)
                            }
                        }

                        FieldPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                FieldSectionHeader(title: "Dokumentation")
                                Text("docs/SCIENTIFIC_ALPHA.md · docs/RESEARCH_GAP_INVENTORY.md · docs/EVALUATION.md · docs/references/unterrichtsvideographie.md")
                                    .font(.footnote)
                                    .foregroundStyle(NativeTheme.dayInkSecondary)
                            }
                        }

                        FieldPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                FieldSectionHeader(title: "Umfang")
                                Text("Enthalten: lokale Sitzungsverwaltung, Geräteeigentümer-Zugriffsschutz, zweckgebundene Einwilligung, kontinuierliche Aufnahme, technische Observierbarkeit, Medienwiedergabe, Zeitmarken, strukturierte Reflexion und vorab protokollierter Metadatenexport.")
                                    .font(.caption)
                                    .foregroundStyle(NativeTheme.dayInkSecondary)
                                Text("Nicht enthalten: Multi-Cam-Synchronisation, Schnitt, Portal-Upload, institutionelle Datenschutzfreigabe, automatische pädagogische Bewertung, psychometrische Validierung oder Wirksamkeitsnachweis.")
                                    .font(.caption)
                                    .foregroundStyle(NativeTheme.dayInkTertiary)
                            }
                        }

                        FieldPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                FieldSectionHeader(title: "Plattform")
                                factRow("Zielgeräte", "iPhone & iPad (iOS 17+)", id: "info.platform")
                                factRow("Sensoren", "Kamera, Mikrofon, Gyroskop/Lage")
                                factRow("Speicherung", "lokal, sitzungsgebunden")
                                factRow("Standardmodus", "evidenzsicher")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .fieldInstrumentDaySurface()
        }
    }

    private func factRow(
        _ key: String,
        _ value: String,
        monospaced: Bool = false,
        id: String? = nil
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                factKey(key)
                factValue(value, monospaced: monospaced, id: id)
            }
            VStack(alignment: .leading, spacing: 3) {
                factKey(key)
                factValue(value, monospaced: monospaced, id: id)
            }
        }
        .padding(.vertical, 4)
    }

    private func factKey(_ key: String) -> some View {
        Text(key)
            .font(.caption.weight(.semibold))
            .foregroundStyle(NativeTheme.dayInkTertiary)
            .frame(width: 130, alignment: .leading)
    }

    private func factValue(_ value: String, monospaced: Bool, id: String?) -> some View {
        Text(value)
            .font(monospaced ? .system(.footnote, design: .monospaced) : .footnote)
            .foregroundStyle(NativeTheme.dayInkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(OptionalInfoAccessibilityIdentifier(id))
    }
}

private struct OptionalInfoAccessibilityIdentifier: ViewModifier {
    let id: String?

    init(_ id: String?) { self.id = id }

    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

#Preview {
    AboutView()
}

#Preview("Info · Große Schrift") {
    AboutView()
        .environment(\.dynamicTypeSize, .accessibility3)
}
