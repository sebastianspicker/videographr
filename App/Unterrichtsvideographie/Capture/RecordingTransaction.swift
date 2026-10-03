import Foundation
import SessionCore

/// Immutable identity carried by every asynchronous recording event.
/// A later capture run must never accept an event for an earlier transaction.
struct RecordingTransaction: Hashable, Sendable {
    let sessionID: UUID
    let transactionID: UUID
    let generation: Int
}

/// Immutable recording inputs prepared by the persistence layer before AVFoundation starts.
struct RecordingStartRequest {
    let url: URL
    let stagedURL: URL
    let allowDespiteWarnings: Bool
    let readiness: SessionReadiness
    let plannedDurationMinutes: Int
    let sessionID: UUID
    let transactionID: UUID
    let artifacts: any RecordingArtifactSecuring
}

/// The only persistence capability the capture owner needs: securing a finalized take and
/// discarding the exact transaction staging path. Conformances live outside `Capture/`.
protocol RecordingArtifactSecuring: Sendable {
    func secureFinalizedRecording(at url: URL) throws
    func discardStagedRecording(at url: URL) throws
}
