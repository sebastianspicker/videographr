import SessionCore
import SwiftUI

/// Purpose-first capture setup with scoped authority and explicit experimental gating.
/// Field Instrument day-atelier layout optimized for dense preparation work.
struct SetupView: View {
    @EnvironmentObject var appSession: AppSessionModel

    @State var sessionPendingDeletion: CaptureSession?
    @State var sessionSearchQuery = ""
    @State var consentDocumentIdentifier = ""
    @State var consentDocumentVersion = ""
    @State var participantGroupPseudonym = ""
    @State var consentScopes: Set<ConsentScope> = []
    @State var consentExpires = false
    @State var consentExpiry = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State var experimentalProtocolIdentifier = ""
    @State var experimentalOversightReference = ""
    @State var experimentalExpiry = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State var experimentalDisclosureAcknowledged = false

    var activeGrantCount: Int {
        appSession.session.consentGrants.filter { grant in
            ConsentScope.allCases.contains { grant.authorizes($0) }
        }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProvenanceBar.daySession(
                    appSession.session,
                    activeGrantCount: activeGrantCount
                )

                GeometryReader { geo in
                    let wide = geo.size.width >= 900
                    if wide {
                        HStack(alignment: .top, spacing: 0) {
                            mainScroll
                            readinessRail
                                .frame(width: min(320, geo.size.width * 0.28))
                        }
                    } else {
                        mainScroll
                    }
                }
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .fieldInstrumentDaySurface()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { appSession.save() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("setup.save.toolbar")
                }
            }
            .onAppear(perform: loadFormState)
            .onChange(of: appSession.session.id) { _, _ in loadFormState() }
            .confirmationDialog(
                "Sitzung und lokale Aufnahme löschen?",
                isPresented: Binding(
                    get: { sessionPendingDeletion != nil },
                    set: { if !$0 { sessionPendingDeletion = nil } }
                ),
                presenting: sessionPendingDeletion
            ) { selected in
                Button("Unwiderruflich löschen", role: .destructive) {
                    appSession.deleteSessionAndMedia(selected.id)
                    sessionPendingDeletion = nil
                }
            } message: { selected in
                Text("„\(selected.title)“ und zugehörige lokale Medien werden gelöscht.")
            }
        }
    }

    private var mainScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                storageStatus
                sessionDetails
                capturePlan
                teachingSituation
                context
                scopedConsent
                operatingMode
                setupStatus
                savedSessions
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.immediately)
        .accessibilityIdentifier("setup.scroll")
    }

    private var hero: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                FieldEyebrow(text: "Neue Sitzung")
                Text("Aufnahme vorbereiten")
                    .font(.largeTitle.weight(.semibold))
                    .tracking(-0.4)
                    .foregroundStyle(NativeTheme.dayInk)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Text("sess · \(appSession.session.id.uuidString.prefix(8).lowercased())")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(NativeTheme.dayInkSecondary)
                Text("Geplant · \(appSession.session.plannedDurationMinutes) Min. · \(appSession.session.teachingSituationPreset.titleDE)")
                    .font(.caption)
                    .foregroundStyle(NativeTheme.dayInkTertiary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

#Preview {
    SetupView().environmentObject(AppSessionModel())
}
