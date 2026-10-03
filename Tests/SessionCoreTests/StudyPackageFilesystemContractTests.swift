import Foundation
import XCTest
@testable import SessionCore

final class StudyPackageFilesystemContractTests: XCTestCase {
    func testValidatedPackageMemberURLsAcceptsExactlyTheContractMembers() throws {
        try withPackage { packageURL in
            let members = try StudyPackageDirectory.validatedMemberURLs(in: packageURL)
            XCTAssertEqual(Set(members.keys), Set(StudyPackageContract.expectedPackageFiles))
        }
    }

    func testValidatedPackageMemberURLsRejectsExtraRegularFile() throws {
        try withPackage { packageURL in
            try Data("video".utf8).write(to: packageURL.appendingPathComponent("take.mp4"))
            XCTAssertThrowsError(try StudyPackageDirectory.validatedMemberURLs(in: packageURL))
        }
    }

    func testValidatedPackageMemberURLsRejectsDirectoryAndSymbolicLink() throws {
        try withPackage { packageURL in
            let directory = packageURL.appendingPathComponent("session.json", isDirectory: true)
            try FileManager.default.removeItem(at: directory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            XCTAssertThrowsError(try StudyPackageDirectory.validatedMemberURLs(in: packageURL))
        }

        try withPackage { packageURL in
            let link = packageURL.appendingPathComponent("session.json")
            try FileManager.default.removeItem(at: link)
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: URL(fileURLWithPath: "/dev/null"))
            XCTAssertThrowsError(try StudyPackageDirectory.validatedMemberURLs(in: packageURL))
        }
    }

    private func withPackage(_ body: (URL) throws -> Void) throws {
        let packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyPackageFilesystemContractTests-\(UUID().uuidString).videographrstudy", isDirectory: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: packageURL) }
        for name in StudyPackageContract.expectedPackageFiles {
            try Data(name.utf8).write(to: packageURL.appendingPathComponent(name))
        }
        try body(packageURL)
    }
}
