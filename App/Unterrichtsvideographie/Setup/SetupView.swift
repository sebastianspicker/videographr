import SessionCore
import ExperimentalResearch
import SwiftUI

/// Session preparation keeps editable context and documented authority together.
struct SetupView: View {
    @EnvironmentObject var appStore: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var onContinue: () -> Void = {}
    enum PreparationField: Hashable { case title, subject, grade, goal, document, version, group, site, contextNotes }
    @FocusState var focusedField: PreparationField?

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
    @State private var showingSessions = false
    @State private var continuing = false

    var activeGrantCount: Int {
        appStore.session.consentGrants.filter { grant in
            ConsentScope.allCases.contains { grant.authorizes($0) }
        }.count
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        preparationHeader
                        if geometry.size.width >= 850 && !dynamicTypeSize.isAccessibilitySize {
                            HStack(alignment: .top, spacing: 32) {
                                contextColumn.frame(maxWidth: .infinity)
                                Rectangle().fill(NativeTheme.nightHairline).frame(width: 1)
                                authorityColumn.frame(maxWidth: .infinity)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        } else {
                            contextColumn
                            authorityColumn
                        }
                        preparationFooter
                    }
                    .padding(geometry.size.width >= 850 ? 28 : 18)
                    .frame(maxWidth: 1_280)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .accessibilityIdentifier("setup.scroll")
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    continueButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(NativeTheme.nightCanvas)
                        .overlay(alignment: .top) {
                            Rectangle().fill(NativeTheme.nightHairline).frame(height: 1)
                        }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { focusedField = nil }
                }
            }
            .onSubmit {
                switch focusedField {
                case .title: focusedField = .subject
                case .subject: focusedField = .grade
                case .grade: focusedField = .goal
                case .document: focusedField = .version
                case .version: focusedField = .group
                default: focusedField = nil
                }
            }
            .fieldInstrumentDaySurface()
            .onAppear(perform: loadFormState)
            .onChange(of: appStore.session.id) { _, _ in loadFormState() }
            .sheet(isPresented: $showingSessions) { sessionsSheet }
        }
    }

    private var preparationHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text("Sitzung vorbereiten").font(.title2.weight(.medium))
                Spacer()
                Button("Sitzungen", systemImage: "tray") { showingSessions = true }
                    .buttonStyle(ScientificButtonStyle())
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Sitzung vorbereiten").font(.title2.weight(.medium))
                Button("Sitzungen", systemImage: "tray") { showingSessions = true }
                    .buttonStyle(ScientificButtonStyle())
            }
        }
    }

    private var contextColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Unterrichtskontext").font(.headline)
            sessionDetails
            context
            capturePlan
            DisclosureGroup("Weitere Angaben und Aufnahmeplanung") {
                VStack(alignment: .leading, spacing: 20) {
                    additionalContext
                    analysisFocus
                    teachingSituation
                    retention
                }
                .padding(.top, 16)
            }
            .accessibilityIdentifier("setup.additionalDetails")
        }
    }

    private var authorityColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            scopedConsent
            DisclosureGroup("Betriebsmodus und Forschungsprotokoll") {
                modePanel.padding(.top, 12)
            }
            .accessibilityIdentifier("setup.modeDetails")
        }
    }

    private var preparationFooter: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().overlay(NativeTheme.nightHairline)
            saveSummary
            if let error = appStore.lastStoreError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(NativeTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var saveSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(appStore.saveState.titleDE, systemImage: saveStateSymbol)
                .font(.subheadline).foregroundStyle(saveStateColor)
                .accessibilityIdentifier("setup.saveState")
            Text("Die App dokumentiert Freigaben. Die institutionelle Prüfung bleibt erforderlich.")
                .font(.caption).foregroundStyle(NativeTheme.nightInkSecondary)
            Text("Aufbewahrung ist eine Vorgabe; keine automatische Löschung.")
                .font(.caption).foregroundStyle(NativeTheme.nightInkSecondary)
        }
    }

    private var continueButton: some View {
        Button {
            focusedField = nil
            continuing = true
            Task { @MainActor in
                let saved = await appStore.flushPendingChanges()
                continuing = false
                if saved { onContinue() }
            }
        } label: {
            HStack {
                if continuing { ProgressView() }
                Text(continuing ? "Sitzung wird gesichert…" : "Speichern und Aufnahme prüfen")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(ScientificButtonStyle(prominent: true))
        .disabled(continuing)
        .keyboardShortcut(.return, modifiers: .command)
        .accessibilityIdentifier("setup.saveAndContinue")
    }

    private var sessionsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button("Neue Sitzung", systemImage: "plus") {
                        appStore.newSession()
                        showingSessions = false
                    }
                    .buttonStyle(ScientificButtonStyle(prominent: true))
                    .accessibilityIdentifier("setup.newSession")
                    if appStore.allSessions.isEmpty {
                        ContentUnavailableView("Noch keine gespeicherten Sitzungen", systemImage: "tray",
                            description: Text("Bereiten Sie eine lokale Sitzung vor oder importieren Sie später ein Video zur Reflexion."))
                    } else {
                        savedSessions
                    }
                }
                .padding(20)
            }
            .navigationTitle("Lokale Sitzungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { showingSessions = false }
                }
            }
            .fieldInstrumentDaySurface()
            .confirmationDialog(
                "Sitzung und lokale Aufnahme löschen?",
                isPresented: Binding(
                    get: { sessionPendingDeletion != nil },
                    set: { if !$0 { sessionPendingDeletion = nil } }
                ),
                presenting: sessionPendingDeletion
            ) { selected in
                Button("Unwiderruflich löschen", role: .destructive) {
                    appStore.deleteSessionAndMedia(selected.id)
                    sessionPendingDeletion = nil
                }
            } message: { selected in
                Text("„\(selected.title)“ und zugehörige lokale Medien werden gelöscht. Importquellen und bereits weitergegebene Kopien bleiben bestehen.")
            }
        }
    }
}

#Preview {
    SetupView().environmentObject(AppStore())
}
