import Foundation
import XCTest

final class AppIntegritySourceContractTests: XCTestCase {
    private func source(_ relativePath: String) throws -> String {
        try repositorySwiftSources(relativePath)
    }

    func testRecordingLifecycleWiresFrozenAuthorizationDeadlineAndTerminalFailure() throws {
        let appModel = try source("App/Unterrichtsvideographie/AppSessionModel.swift")
        let live = try source("App/Unterrichtsvideographie/Live/LiveGuidanceView.swift")
        let camera = try source("App/Unterrichtsvideographie/Live/CameraSessionModel.swift")

        for token in [
            "captureAuthorizationSnapshot(at: preparedAt)",
            "values.lifecycleState = .prepared",
            "func recordingDidFail(",
            "failAbandonedTakes(",
            "includeJournals: true"
        ] {
            XCTAssertTrue(appModel.contains(token), "Missing recording integrity boundary: \(token)")
        }
        for token in [
            "scheduleAuthorizationDeadline(for: prepared)",
            "guard appSession.recordingAuthorizationIsValid(prepared)",
            "await appSession.cancelPreparedRecording(prepared)",
            "activePreparedRecording = prepared",
            "syncCaptureAuthorization()",
            "onRecordingBegan",
            "onRecordingFailed",
            "transactionID: prepared.transactionID"
        ] {
            XCTAssertTrue(live.contains(token), "Missing Live transaction wiring: \(token)")
        }
        XCTAssertTrue(camera.contains("var onRecordingFailed:"))
        XCTAssertTrue(camera.contains("transaction.transactionID != transactionID"))
    }

    func testDisclosureIsPreAuditedAndTemporaryPackageIsOutcomeScoped() throws {
        let appModel = try source("App/Unterrichtsvideographie/AppSessionModel.swift")
        let reflect = try source("App/Unterrichtsvideographie/Reflect/ReflectView.swift")

        for token in [
            "func prepareExportForSharing()",
            "values.status = .attempted",
            "func recordExportOutcome(",
            "reconcileOpenExportAttempts",
            "status: .outcomeUnknown",
            "exportID: preparation.eventID",
            "private let leases = ExportPackageLeaseRegistry()",
            "await leases.acquire(destination)",
            "removeUnleasedPackages(for: sessionID)",
            "removePackage(at: prepared.packageURL)"
        ] {
            XCTAssertTrue(appModel.contains(token), "Missing disclosure outbox boundary: \(token)")
        }
        XCTAssertTrue(reflect.contains("await appSession.prepareExportForSharing()"))
        XCTAssertTrue(reflect.contains("await appSession.recordExportOutcome("))
    }

    func testWholeAppUsesDeviceOwnerAuthenticationWithDebugOnlyE2EBypass() throws {
        let app = try source("App/Unterrichtsvideographie/UnterrichtsvideographieApp.swift")
        XCTAssertTrue(app.contains(".deviceOwnerAuthentication"))
        XCTAssertTrue(app.contains("#if DEBUG"))
        XCTAssertTrue(app.contains("VIDEOGRAPHR_E2E_SESSION"))
        XCTAssertTrue(app.contains("operatorAccess.lock()"))
        XCTAssertTrue(app.contains("authenticationGeneration"))
    }
}
