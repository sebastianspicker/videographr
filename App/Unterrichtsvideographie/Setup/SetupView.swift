import SessionCore
import ExperimentalResearch
import SwiftUI

/// Session preparation keeps editable context and documented authority together.
/// The page reads as a numbered protocol: context, consent, mode.
struct SetupView: View {
    @EnvironmentObject var appStore: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var sizeClass
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
    @State var showingSessions = false
    @State private var continuing = false
    @ScaledMetric(relativeTo: .footnote) private var statusKeyWidth: CGFloat = 72

    var activeGrantCount: Int {
        appStore.session.consentGrants.filter { grant in
            ConsentScope.allCases.contains { grant.authorizes($0) }
        }.count
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let wide = geometry.size.width >= 900 && !dynamicTypeSize.isAccessibilitySize
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xl) {
                        preparationHeader
                        if wide {
                            HStack(alignment: .top, spacing: Space.xxl) {
                                protocolColumn.frame(maxWidth: .infinity, alignment: .leading)
                                protocolStatus.frame(width: 264)
                            }
                        } else {
                            protocolStatus
                            protocolColumn
                        }
                        preparationFooter
                    }
                    .padding(.horizontal, sizeClass == .regular ? Space.gutterRegular : Space.gutterCompact)
                    .padding(.top, Space.xl)
                    .padding(.bottom, Space.xxl)
                    .frame(maxWidth: Space.pageMaximum, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .accessibilityIdentifier("setup.scroll")
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !dynamicTypeSize.isAccessibilitySize { actionBar }
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
            .paperSurface()
            .onAppear(perform: loadFormState)
            .onChange(of: appStore.session.id) { _, _ in loadFormState() }
            .sheet(isPresented: $showingSessions) { sessionsSheet }
        }
    }

    private var sessionTitle: String {
        let title = appStore.session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Neue Sitzung" : title
    }

    private var preparationHeader: some View {
        DocumentHeader(eyebrow: "Sitzung vorbereiten", title: sessionTitle) {
            Button { showingSessions = true } label: {
                Label("Alle Sitzungen", systemImage: "tray.full")
            }
            .buttonStyle(InkButtonStyle(kind: sizeClass == .regular ? .secondary : .quiet))
            .accessibilityIdentifier("setup.sessions")
        }
    }

    private var protocolColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProtocolSection("1", "Unterrichtskontext") {
                sessionDetails
                context
                DisclosureGroup("Weitere Angaben und Aufnahmeplanung") {
                    VStack(alignment: .leading, spacing: Space.l) {
                        additionalContext
                        analysisFocus
                        teachingSituation
                        retention
                    }
                    .padding(.top, Space.s)
                }
                .disclosureGroupStyle(InkDisclosureStyle())
                .accessibilityIdentifier("setup.additionalDetails")
            }
            ProtocolSection(
                "2", "Dokumentierte Freigaben",
                note: "Die App dokumentiert, welche Zwecke freigegeben sind. Eine institutionelle Prüfung ersetzt sie nicht."
            ) {
                consentPanel
            }
            ProtocolSection("3", "Betriebsmodus") {
                modePanel
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("setup.modeDetails")
        }
    }

    // MARK: Protocol status

    private var protocolStatus: some View {
        VStack(alignment: .leading, spacing: 0) {
            FormLabel("Protokollstand")
                .padding(.bottom, Space.s)
            Rule(strong: true)
            statusRow("Kontext") {
                appStore.session.context.isMinimallyComplete
                    && !appStore.session.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? StatusMark("Vollständig", kind: .secured)
                    : StatusMark("Unvollständig", kind: .open)
            }
            statusRow("Freigaben") {
                appStore.session.canStartNewCapture
                    ? StatusMark("Dokumentiert", kind: .secured)
                    : StatusMark("Erhebung oder Reflexion fehlt", kind: .attention)
            }
            statusRow("Modus") {
                appStore.session.operatingMode == .evidenceSafe
                    ? StatusMark("Evidence-safe", kind: .neutral)
                    : StatusMark("Experimentell", kind: .hypothesis)
            }
            statusRow("Speicher") {
                SaveStateMark(state: appStore.saveState)
            }
            .accessibilityIdentifier("setup.saveState")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Protokollstand")
    }

    private func statusRow<Mark: View>(_ key: String, @ViewBuilder mark: () -> Mark) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    FormLabel(key, small: true)
                    mark()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                    FormLabel(key, small: true).frame(width: statusKeyWidth, alignment: .leading)
                    mark().frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, Space.s + 2)
        .overlay(alignment: .bottom) { Rule() }
        .accessibilityElement(children: .combine)
    }

    private var preparationFooter: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if dynamicTypeSize.isAccessibilitySize {
                SaveStateMark(state: appStore.saveState)
                continueButton(fullWidth: true)
                    .padding(.bottom, Space.l)
            }
            if let error = appStore.lastStoreError {
                StatusMark(error, kind: .fault, prominent: true)
            }
            Text("Aufbewahrungsangaben sind dokumentierte Vorgaben. Die App löscht nichts automatisch.")
                .font(Typeface.captionSmall)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Action bar

    private var actionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.l) {
                SaveStateMark(state: appStore.saveState)
                Spacer(minLength: Space.m)
                continueButton(fullWidth: false)
            }
            continueButton(fullWidth: true)
        }
        .padding(.horizontal, sizeClass == .regular ? Space.gutterRegular : Space.gutterCompact)
        .padding(.vertical, Space.m)
        .background(Ink.sheet)
        .overlay(alignment: .top) { Rule() }
    }

    private func continueButton(fullWidth: Bool) -> some View {
        Button {
            focusedField = nil
            continuing = true
            Task { @MainActor in
                let saved = await appStore.flushPendingChanges()
                continuing = false
                if saved { onContinue() }
            }
        } label: {
            HStack(spacing: Space.s) {
                if continuing { ProgressView().tint(Ink.onHuman) }
                Text(continuing ? "Sitzung wird gesichert …" : "Speichern und Aufnahme prüfen")
                    .fixedSize(horizontal: false, vertical: true)
                if !continuing && !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "arrow.right").accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(InkButtonStyle(kind: .primary, fullWidth: fullWidth))
        .disabled(continuing)
        .keyboardShortcut(.return, modifiers: .command)
        .accessibilityIdentifier("setup.saveAndContinue")
    }
}

#Preview {
    SetupView().environmentObject(AppStore())
}
