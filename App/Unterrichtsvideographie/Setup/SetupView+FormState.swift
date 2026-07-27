import GuidanceEngine
import SessionCore
import SwiftUI

extension SetupView {
    var canActivateExperimentalMode: Bool {
        !experimentalProtocolIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !experimentalOversightReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && experimentalExpiry > Date()
            && experimentalDisclosureAcknowledged
            && appSession.session.authorizes(.researchProcessing)
    }

    var saveStateSymbol: String {
        switch appSession.saveState {
        case .saved: return "checkmark.circle"
        case .unsaved: return "pencil.circle"
        case .saving: return "arrow.triangle.2.circlepath"
        case .failed: return "exclamationmark.triangle"
        }
    }

    var saveStateColor: Color {
        switch appSession.saveState {
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
        .accessibilityIdentifier("setup.consent.scope.\(scope.rawValue)")
    }

    func sessionBinding<Value>(_ keyPath: WritableKeyPath<CaptureSession, Value>) -> Binding<Value> {
        Binding(
            get: { appSession.session[keyPath: keyPath] },
            set: { value in
                appSession.session[keyPath: keyPath] = value
                appSession.markDirty()
            }
        )
    }

    func contextBinding(_ keyPath: WritableKeyPath<SessionContext, String>) -> Binding<String> {
        Binding(
            get: { appSession.session.context[keyPath: keyPath] },
            set: { value in
                appSession.session.context[keyPath: keyPath] = value
                appSession.markDirty()
            }
        )
    }

    func loadFormState() {
        guard let grant = appSession.session.consentGrants.last(where: { $0.withdrawnAt == nil }) else {
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
        if let protocolReference = appSession.session.experimentalProtocol {
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
