import Foundation
import XCTest

final class ExportOutcomeSourceContractTests: XCTestCase {
    private func source(_ relativePath: String) throws -> String {
        try repositorySwiftSources(relativePath)
    }

    func testShareCompletionHasOneCoordinatorAndDismissalIsNextTurnFallback() throws {
        let reflect = try source("App/Unterrichtsvideographie/Reflect/ReflectView.swift")
        let appModel = try source("App/Unterrichtsvideographie/AppSessionModel.swift")
        let event = try source("Sources/SessionCore/SessionIntegrityModels.swift")

        for token in [
            "ExportOutcomeCoordinator(exportID: prepared.id)",
            "recordActivityCompletion",
            "recordDismissal()",
            "await Task.yield()",
            "dismissalFallbackIfNeeded()"
        ] {
            XCTAssertTrue(reflect.contains(token), "Missing share outcome coordinator boundary: \(token)")
        }
        XCTAssertTrue(event.contains("guard status != .attempted, self.status == .attempted else { return false }"))
        XCTAssertTrue(appModel.contains("guard await leases.release(packageURL) else { return }"))
    }
}
