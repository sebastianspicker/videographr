import Foundation
import SessionCore
import XCTest

final class ExportPackageLeaseRegistryTests: XCTestCase {
    private func attemptedEvent() -> ExportEvent {
        ExportEvent({
    var values = ExportEvent.Values()
    values.operatorPseudonym = "operator"
    values.includedScopes = [.secondaryUse, .externalSharing]
    values.fileDigests = ["manifest.json": "digest"]
    values.status = .attempted
    return values
}())
    }

    @MainActor
    private func assertCompletedOutcome(
        coordinator: ExportOutcomeCoordinator,
        leases: ExportPackageLeaseRegistry,
        packageURL: URL,
        event: inout ExportEvent
    ) async {
        XCTAssertTrue(event.finish(status: .completed, shareActivityIdentifier: "mail", failureDescription: nil))
        let firstCleanup = await leases.release(packageURL)
        XCTAssertTrue(firstCleanup)
        XCTAssertNil(coordinator.dismissalFallbackIfNeeded())
        XCTAssertFalse(event.finish(status: .cancelled, shareActivityIdentifier: nil, failureDescription: nil))
        let duplicateCleanup = await leases.release(packageURL)
        XCTAssertFalse(duplicateCleanup)
        XCTAssertEqual(event.status, .completed)
    }
    private actor PreparationGate {
        private var continuation: CheckedContinuation<Void, Never>?
        private var isOpen = false

        func wait() async {
            guard !isOpen else { return }
            await withCheckedContinuation { continuation = $0 }
        }

        func open() {
            isOpen = true
            continuation?.resume()
            continuation = nil
        }
    }

    func testInvalidationInterleavedWithPreparationKeepsArtifactUntilOutcome() async throws {
        let root = testTemporaryDirectory(named: "ExportPackageLeaseRegistryTests")
        let packageURL = root.appendingPathComponent("prepared.videographrstudy", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let manifestURL = packageURL.appendingPathComponent("manifest.json")

        let leases = ExportPackageLeaseRegistry()
        let gate = PreparationGate()
        let preparationStarted = expectation(description: "preparation acquired its lease")
        let preparation = Task {
            await leases.acquire(packageURL) // Reserve before writing the package.
            try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
            try Data("readable while leased".utf8).write(to: manifestURL)
            preparationStarted.fulfill()
            await gate.wait() // Keep preparation open while invalidation interleaves.
        }
        await fulfillment(of: [preparationStarted], timeout: 1)

        let invalidation = Task { () throws in
            for url in await leases.unleasedPackages(in: [packageURL]) {
                try FileManager.default.removeItem(at: url)
            }
        }
        try await invalidation.value
        XCTAssertEqual(try Data(contentsOf: manifestURL), Data("readable while leased".utf8))

        await gate.open()
        try await preparation.value
        let outcomeCleanup = await leases.release(packageURL) // recordExportOutcome is terminal.
        XCTAssertTrue(outcomeCleanup)
        let invalidatedAfterOutcome = await leases.unleasedPackages(in: [packageURL])
        for url in invalidatedAfterOutcome {
            try FileManager.default.removeItem(at: url)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: packageURL.path))
    }

    @MainActor
    func testCompletionThenDismissalRecordsOneAuthoritativeOutcomeAndCleanup() async {
        let coordinator = ExportOutcomeCoordinator(exportID: UUID())
        let leases = ExportPackageLeaseRegistry()
        let packageURL = URL(fileURLWithPath: "/tmp/completion-first.videographrstudy")
        await leases.acquire(packageURL)
        var event = attemptedEvent()
        let completion = coordinator.recordActivityCompletion(
            completed: true,
            shareActivityIdentifier: "mail",
            failureDescription: nil
        )
        coordinator.recordDismissal()

        XCTAssertTrue(completion?.completed == true)
        await assertCompletedOutcome(
            coordinator: coordinator,
            leases: leases,
            packageURL: packageURL,
            event: &event
        )
        XCTAssertNil(coordinator.recordActivityCompletion(
            completed: false,
            shareActivityIdentifier: nil,
            failureDescription: nil
        ))
    }

    @MainActor
    func testDismissalThenLateCompletionWinsBeforeFallbackAndAllowsOneCleanup() async {
        let coordinator = ExportOutcomeCoordinator(exportID: UUID())
        let leases = ExportPackageLeaseRegistry()
        let packageURL = URL(fileURLWithPath: "/tmp/dismissal-first.videographrstudy")
        await leases.acquire(packageURL)
        var event = attemptedEvent()
        coordinator.recordDismissal()
        let completion = coordinator.recordActivityCompletion(
            completed: true,
            shareActivityIdentifier: "mail",
            failureDescription: nil
        )

        XCTAssertTrue(completion?.completed == true)
        await assertCompletedOutcome(
            coordinator: coordinator,
            leases: leases,
            packageURL: packageURL,
            event: &event
        )
    }

    func testAttemptedToAttemptedTransitionIsRejectedWithoutMutation() {
        var event = attemptedEvent()
        let original = event

        XCTAssertFalse(event.finish(status: .attempted, shareActivityIdentifier: nil, failureDescription: nil))
        XCTAssertEqual(event, original)
    }
}
