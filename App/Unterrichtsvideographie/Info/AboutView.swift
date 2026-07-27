import SwiftUI
import GuidanceEngine

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

                List {
                    Section("Videographr") {
                        LabeledContent("Produkt", value: "Videographr")
                        LabeledContent("Version", value: BuildIdentity.current.displayVersion)
                        LabeledContent("Domäne", value: "Unterrichtsvideographie")
                        Text("Lokale Alpha-Software für kontinuierliche Videoaufnahme und evidenzverknüpfte Reflexion in der Lehrkräftebildung. Kein validiertes Kodierinstrument, kein Wirksamkeitsnachweis und kein Video-Portal.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("info.content")
                    }
                    Section("Normalbetrieb: evidenzsicher") {
                        Text("Setup mit zweckgebundener Einwilligung → technische Aufnahmehinweise zu Horizont, Kameraruhe, Belichtung, sichtbaren Bildstrukturen und Audiopegel → Reflexion mit selbst gesetzten Zeitmarken.")
                            .font(.body)
                        Text("Bildstruktur-Signale beschreiben nur Beobachtbarkeit. Sie erkennen weder Unterrichtsqualität noch Lernen, Aufmerksamkeit, Feedback oder Beteiligung.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section("Experimenteller Modus") {
                        Label("Unvalidierte regelbasierte Hypothesen", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Nur nach Eingabe einer gültigen Protokoll- und Aufsichtsreferenz. Regelaktivierungen werden dauerhaft getrennt vom Normalbetrieb gekennzeichnet und dürfen nicht als Wahrscheinlichkeit, menschlicher Code oder pädagogische Bewertung interpretiert werden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section("Technischer Datenweg") {
                        Text("CoreMotion und AVCapture → lokale Signalextraktion → technische Aufnahmehinweise → lokaler SessionStore. Video, Metadaten und Reflexion bleiben ohne ausdrückliche Freigabe im App-Speicher.")
                            .font(.footnote)
                        Text("Der lokale Zugriff ist durch die iOS-Geräteeigentümer-Authentifizierung geschützt. Ein Audit-Pseudonym ist keine bestätigte Identität.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section("Nachweisstand") {
                        LabeledContent("Claim-Register", value: "v\(EvidenceClaimRegistry.version)")
                        Text(EvidenceClaimRegistry.claims.first?.allowedWordingDE ?? "Die App meldet direkt beobachtbare Aufnahmebedingungen.")
                            .font(.footnote)
                        Text("Der aktuelle Stand belegt Implementierung und automatisierte Tests. Geräte-, Human-Rater- und Wirksamkeitsvalidierung sind getrennte, noch nicht erfüllte Stufen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section("Dokumentation") {
                        Text("docs/SCIENTIFIC_ALPHA.md · docs/RESEARCH_GAP_INVENTORY.md · docs/EVALUATION.md · docs/references/unterrichtsvideographie.md")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Section("Umfang") {
                        Text("Enthalten: lokale Sitzungsverwaltung, Geräteeigentümer-Zugriffsschutz, zweckgebundene Einwilligung, kontinuierliche Aufnahme, technische Observierbarkeit, Medienwiedergabe, Zeitmarken, strukturierte Reflexion und vorab protokollierter Metadatenexport.")
                            .font(.caption)
                        Text("Nicht enthalten: Multi-Cam-Synchronisation, Schnitt, Portal-Upload, institutionelle Datenschutzfreigabe, automatische pädagogische Bewertung, psychometrische Validierung oder Wirksamkeitsnachweis.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section("Plattform") {
                        LabeledContent("Zielgeräte", value: "iPhone & iPad (iOS 17+)")
                            .accessibilityIdentifier("info.platform")
                        LabeledContent("Sensoren", value: "Kamera, Mikrofon, Gyroskop/Lage")
                        LabeledContent("Speicherung", value: "lokal, sitzungsgebunden")
                        LabeledContent("Standardmodus", value: "evidenzsicher")
                    }
                }
            }
            .navigationTitle("Info")
            .fieldInstrumentDaySurface()
        }
    }
}

#Preview {
    AboutView()
}
