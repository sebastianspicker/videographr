import Foundation

/// Transaction-keyed ownership for promoted recordings awaiting metadata confirmation.
///
/// A promoted artifact remains owned until its exact transaction confirms or rolls it back.
/// Distinct transactions may coexist; only the same normalized destination is a collision.
public struct RecordingArtifactOwnership<Transaction: Hashable> {
    private var destinations: [Transaction: URL] = [:]

    public init() {}

    /// Registers a promoted artifact. Returns `false` when the transaction is already bound to
    /// a different destination or another outstanding transaction owns this destination.
    @discardableResult
    public mutating func register(_ transaction: Transaction, at destination: URL) -> Bool {
        let normalizedDestination = destination.standardizedFileURL
        if let currentDestination = destinations[transaction] {
            return currentDestination == normalizedDestination
        }
        guard !destinations.values.contains(where: { $0 == normalizedDestination }) else { return false }
        destinations[transaction] = normalizedDestination
        return true
    }

    /// Returns the registered destination only when the callback supplied its exact URL.
    public func validatedDestination(
        for transaction: Transaction,
        matching candidate: URL
    ) -> URL? {
        let normalizedCandidate = candidate.standardizedFileURL
        guard destinations[transaction] == normalizedCandidate else { return nil }
        return normalizedCandidate
    }

    /// Confirms one transaction and removes only its ownership entry.
    @discardableResult
    public mutating func confirm(_ transaction: Transaction) -> URL? {
        destinations.removeValue(forKey: transaction)
    }

    public func destination(for transaction: Transaction) -> URL? {
        destinations[transaction]
    }

    public func isDestinationOwned(_ destination: URL) -> Bool {
        destinations.values.contains(destination.standardizedFileURL)
    }
}

/// Monotonic foreground watchdog ownership. A callback or timeout can affect only the
/// transaction that most recently armed that phase.
public struct RecordingTransactionWatchdogs<Transaction: Hashable> {
    public enum Phase: Hashable {
        case startAcknowledgement
        case finalization
        case metadataAttachment
    }

    private var transactions: [Phase: Transaction] = [:]

    public init() {}

    public mutating func arm(_ phase: Phase, for transaction: Transaction) {
        transactions[phase] = transaction
    }

    /// Cancels one watchdog only when its terminal callback belongs to its current transaction.
    @discardableResult
    public mutating func cancel(_ phase: Phase, for transaction: Transaction) -> Bool {
        guard transactions[phase] == transaction else { return false }
        transactions[phase] = nil
        return true
    }

    /// Consumes a timeout only when it belongs to the currently armed transaction.
    @discardableResult
    public mutating func expire(_ phase: Phase, for transaction: Transaction) -> Bool {
        cancel(phase, for: transaction)
    }

    public func isArmed(_ phase: Phase, for transaction: Transaction) -> Bool {
        transactions[phase] == transaction
    }
}
