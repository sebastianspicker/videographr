import GuidanceEngine
import SessionCore
import SwiftUI

extension SetupView {
    var canActivateExperimentalMode: Bool {
        !experimentalProtocolIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !experimentalOversightReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && experimentalExpiry > Date()
            && experimentalDisclosureAcknowledged
            && appStore.session.authorizes(.researchProcessing)
    }

    var saveStateSymbol: String {
        switch appStore.saveState {
        case .saved: return "checkmark.circle"
        case .unsaved: return "pencil.circle"
        case .saving: return "arrow.triangle.2.circlepath"
        case .failed: return "exclamationmark.triangle"
        }
    }

    var saveStateColor: Color {
        switch appStore.saveState {
        case .saved: return NativeTheme.positiveDay
        case .unsaved, .saving: return .secondary
        case .failed: return NativeTheme.danger
        }
    }

    func consentScopeToggle(_ scope: ConsentScope, _ title: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { consentScopes.contains(scope) },
            set: { enabled in
                if enabled { consentScopes.insert(scope) } else { consentScopes.remove(scope) }
            }
        ))
        .toggleStyle(ScientificCheckboxStyle())
        .accessibilityIdentifier("setup.consent.scope.\(scope.rawValue)")
    }

    func sessionBinding<Value>(_ keyPath: WritableKeyPath<CaptureSession, Value>) -> Binding<Value> {
        appStore.binding(keyPath)
    }

    func contextBinding(_ keyPath: WritableKeyPath<SessionContext, String>) -> Binding<String> {
        appStore.binding((\CaptureSession.context).appending(path: keyPath))
    }

    func loadFormState() {
        guard let grant = appStore.session.consentGrants.last(where: { $0.withdrawnAt == nil }) else {
            consentDocumentIdentifier = ""
            consentDocumentVersion = ""
            participantGroupPseudonym = ""
            consentScopes = []
            consentExpires = false
            return
        }
        consentDocumentIdentifier = grant.documentIdentifier
        consentDocumentVersion = grant.documentVersion
        participantGroupPseudonym = grant.participantGroupPseudonym
        consentScopes = grant.scopes
        consentExpires = grant.expiresAt != nil
        consentExpiry = grant.expiresAt ?? consentExpiry
        if let protocolReference = appStore.session.experimentalProtocol {
            experimentalProtocolIdentifier = protocolReference.protocolIdentifier
            experimentalOversightReference = protocolReference.oversightReference
            experimentalExpiry = protocolReference.expiresAt
            experimentalDisclosureAcknowledged = true
        } else {
            experimentalProtocolIdentifier = ""
            experimentalOversightReference = ""
            experimentalDisclosureAcknowledged = false
        }
    }
}
