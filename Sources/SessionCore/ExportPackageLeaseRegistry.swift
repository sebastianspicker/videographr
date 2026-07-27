import Foundation

/// Serializes the lifetime of a temporary export package.
///
/// A lease is acquired before package construction begins.  Consequently a
/// concurrent invalidation can collect only artifacts that have no active
/// disclosure outcome to wait for.
public actor ExportPackageLeaseRegistry {
    private var leasedPackages: Set<URL> = []

    public init() {}

    public func acquire(_ packageURL: URL) {
        leasedPackages.insert(packageURL.standardizedFileURL)
    }

    /// Returns true only for the caller that owns the terminal cleanup decision.
    public func release(_ packageURL: URL) -> Bool {
        leasedPackages.remove(packageURL.standardizedFileURL) != nil
    }

    /// Returns the supplied artifacts which are safe for invalidation to remove.
    public func unleasedPackages(in candidates: [URL]) -> [URL] {
        candidates.filter { !leasedPackages.contains($0.standardizedFileURL) }
    }
}

/// Main-actor token which resolves the two UIKit share-sheet callbacks once.
@MainActor
public final class ExportOutcomeCoordinator {
    public struct Outcome: Equatable, Sendable {
        public let completed: Bool
        public let shareActivityIdentifier: String?
        public let failureDescription: String?

        public init(completed: Bool, shareActivityIdentifier: String?, failureDescription: String?) {
            self.completed = completed
            self.shareActivityIdentifier = shareActivityIdentifier
            self.failureDescription = failureDescription
        }
    }

    public let exportID: UUID
    private var terminalOutcome: Outcome?
    private var dismissalObserved = false

    public init(exportID: UUID) {
        self.exportID = exportID
    }

    /// The activity callback is authoritative whenever it arrives before the fallback turn.
    public func recordActivityCompletion(
        completed: Bool,
        shareActivityIdentifier: String?,
        failureDescription: String?
    ) -> Outcome? {
        guard terminalOutcome == nil else { return nil }
        let outcome = Outcome(
            completed: completed,
            shareActivityIdentifier: shareActivityIdentifier,
            failureDescription: failureDescription
        )
        terminalOutcome = outcome
        return outcome
    }

    public func recordDismissal() {
        dismissalObserved = true
    }

    /// Invoke on the next main-actor turn so UIKit completion can win dismissal ordering.
    public func dismissalFallbackIfNeeded() -> Outcome? {
        guard dismissalObserved, terminalOutcome == nil else { return nil }
        let outcome = Outcome(completed: false, shareActivityIdentifier: nil, failureDescription: nil)
        terminalOutcome = outcome
        return outcome
    }
}
