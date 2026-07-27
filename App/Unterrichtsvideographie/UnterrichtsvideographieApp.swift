@preconcurrency import LocalAuthentication
import SwiftUI

/// App entry point for Videographr, a local Unterrichtsvideographie alpha.
///
/// Owns the single `AppSessionModel` (active capture session + local store) and injects it
/// into the five-tab shell: Setup → Live → Reflect → Learn → Info.
@main
struct UnterrichtsvideographieApp: App {
    /// Shared session/store graph for all tabs (MainActor).
    @StateObject private var appSession = AppSessionModel()
    @StateObject private var operatorAccess = OperatorAccessController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                if operatorAccess.isUnlocked {
                    RootTabView()
                        .environmentObject(appSession)
                } else {
                    OperatorAccessGate(
                        message: operatorAccess.message,
                        authenticate: operatorAccess.authenticate
                    )
                }

                if scenePhase != .active {
                    Color.black
                        .ignoresSafeArea()
                        .overlay {
                            Label("Inhalte geschützt", systemImage: "eye.slash.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .accessibilityLabel("Inhalte geschützt, solange die App nicht aktiv ist")
                        .accessibilityIdentifier("app.privacyCover")
                        .accessibilityAddTraits(.isModal)
                }
            }
            .onChange(of: scenePhase) { _, nextPhase in
                if nextPhase == .active {
                    operatorAccess.authenticate()
                } else if nextPhase == .background {
                    operatorAccess.lock()
                }
                if nextPhase == .inactive || nextPhase == .background {
                    Task {
                        _ = await appSession.flushPendingChanges()
                    }
                }
            }
            .task { operatorAccess.authenticate() }
        }
    }
}

@MainActor
private final class OperatorAccessController: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published private(set) var message = "Geräteeigentümer authentifizieren, um lokale Sitzungen zu öffnen."
    private var authenticationInFlight = false
    private var authenticationGeneration = 0

    func lock() {
        authenticationGeneration &+= 1
        authenticationInFlight = false
        isUnlocked = false
        message = "App gesperrt. Geräteeigentümer erneut authentifizieren."
    }

    func authenticate() {
    guard !isUnlocked, !authenticationInFlight else { return }
    if grantsE2EAccess() {
        unlockForE2E()
        return
    }
    let context = LAContext()
    context.localizedCancelTitle = "Abbrechen"
    guard canAuthenticate(with: context) else { return }
    beginAuthentication(with: context)
}

private func unlockForE2E() {
    isUnlocked = true
    message = "Debug-E2E-Zugriff"
}

private func canAuthenticate(with context: LAContext) -> Bool {
    var policyError: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
        message = "Zugriff blockiert: Das Gerät benötigt einen aktivierten Code oder eine biometrische Entsperrung. \(policyError?.localizedDescription ?? "")"
        return false
    }
    return true
}

private func beginAuthentication(with context: LAContext) {
    authenticationInFlight = true
    authenticationGeneration &+= 1
    let requestGeneration = authenticationGeneration
    message = "Authentifizierung läuft…"
    context.evaluatePolicy(
        .deviceOwnerAuthentication,
        localizedReason: "Lokale Unterrichtsvideos, Reflexionen, Export und Löschung schützen"
    ) { [weak self] success, error in
        Task { @MainActor in
            self?.completeAuthentication(
                success: success,
                error: error,
                requestGeneration: requestGeneration
            )
        }
    }
}

private func completeAuthentication(success: Bool, error: Error?, requestGeneration: Int) {
    guard authenticationGeneration == requestGeneration else { return }
    authenticationInFlight = false
    isUnlocked = success
    message = success
        ? "Zugriff freigegeben"
        : "Authentifizierung fehlgeschlagen: \(error?.localizedDescription ?? "Unbekannter Fehler")"
}

    private func grantsE2EAccess() -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["VIDEOGRAPHR_E2E_SESSION"] != nil
        #else
        false
        #endif
    }
}

private struct OperatorAccessGate: View {
    let message: String
    let authenticate: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(NativeTheme.recordAccent)
            Text("Geschützte lokale Sitzungen")
                .font(.title2.bold())
                .foregroundStyle(NativeTheme.nightInk)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(NativeTheme.nightInkSecondary)
            Button("Geräteeigentümer authentifizieren", action: authenticate)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("app.authenticate")
        }
        .padding(32)
        .frame(maxWidth: 460)
        .background(NativeTheme.nightSurface)
        .clipShape(RoundedRectangle(cornerRadius: NativeTheme.cardCornerRadius * 2, style: .continuous))
        .padding(24)
        .background(NativeTheme.nightCanvas.ignoresSafeArea())
        .tint(NativeTheme.recordAccent)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("app.accessGate")
    }
}
