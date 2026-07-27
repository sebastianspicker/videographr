import AVFoundation
import CryptoKit
import Foundation
import SessionCore

private struct PackageManifestInput {
    let projection: StudyExportProjection
    let provenance: BuildProvenance
    let files: [(String, Data)]
    let digests: [String: String]
}

actor StudyPackageBuilder {
    private let leases = ExportPackageLeaseRegistry()
    init() {
        let fileManager = FileManager.default
        for url in Self.startupArtifacts(fileManager: fileManager) {
            if Self.shouldRemoveStartupArtifact(url) {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private static func shouldRemoveStartupArtifact(_ url: URL) -> Bool {
        if Self.packageSessionID(from: url) != nil { return true }
        let name = url.lastPathComponent
        return name.hasPrefix(".") && ["tmp", "replacement"].contains(url.pathExtension)
    }

    private static func startupArtifacts(fileManager: FileManager) -> [URL] {
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("VideographrExports", isDirectory: true)
            .standardizedFileURL
        guard (try? fileManager.destinationOfSymbolicLink(atPath: root.path)) == nil,
              let values = try? root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true, values.isSymbolicLink != true
        else { return [] }
        return (try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsSubdirectoryDescendants]
        )) ?? []
    }

    func build(session: CaptureSession, exportID: UUID, provenance: BuildProvenance) async throws -> URL {
        let fileManager = FileManager.default
        let root = try preparedTemporaryRoot(fileManager)
        let destination = packageDestination(in: root, sessionID: session.id, exportID: exportID)
        await leases.acquire(destination)
        do {
            try writePackage(session: session, provenance: provenance, at: destination, in: root)
            return destination
        } catch {
            await discardPackage(destination, fileManager: fileManager)
            throw error
        }
    }

    private func preparedTemporaryRoot(_ fileManager: FileManager) throws -> URL {
        let root = try temporaryRoot(fileManager: fileManager)
        try applyTemporaryProtection(to: root)
        try removeStaleTemporaryPackages(in: root)
        return root
    }

    private func packageDestination(in root: URL, sessionID: UUID, exportID: UUID) -> URL {
        root.appendingPathComponent(
            "\(sessionID.uuidString)--\(exportID.uuidString).videographrstudy",
            isDirectory: true
        )
    }

    private func writePackage(
        session: CaptureSession,
        provenance: BuildProvenance,
        at destination: URL,
        in root: URL
    ) throws {
        let fileManager = FileManager.default
        let staging = root.appendingPathComponent(
            ".\(session.id.uuidString)-\(UUID().uuidString).tmp",
            isDirectory: true
        )
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        try applyTemporaryProtection(to: staging)
        defer { try? fileManager.removeItem(at: staging) }
        let projection = StudyExportProjection.make(from: session)
        let files = try exportFiles(from: projection)
        let digests = try write(files, into: staging)
        try writeManifest(
            PackageManifestInput(
                projection: projection,
                provenance: provenance,
                files: files,
                digests: digests
            ),
            into: staging
        )
        try fileManager.moveItem(at: staging, to: destination)
        _ = try validatedManifest(at: destination, expectedSessionID: session.id)
    }

    private func exportFiles(from projection: StudyExportProjection) throws -> [(String, Data)] {
        [
            ("session.json", try canonicalData(projection.session)),
            ("annotations.jsonl", try jsonLines(projection.annotations)),
            ("observations.jsonl", try jsonLines(projection.observations)),
            ("coding-snapshots.jsonl", try jsonLines(projection.codingSnapshots))
        ]
    }

    private func write(_ files: [(String, Data)], into directory: URL) throws -> [String: String] {
        var digests: [String: String] = [:]
        for (name, data) in files {
            let fileURL = directory.appendingPathComponent(name)
            try data.write(to: fileURL, options: .atomic)
            try applyTemporaryProtection(to: fileURL)
            digests[name] = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        return digests
    }

    private func writeManifest(_ input: PackageManifestInput, into directory: URL) throws {
        guard input.projection.requiredScopes.allSatisfy({ input.projection.session.authorizes($0) }) else {
            throw CocoaError(.fileWriteNoPermission, userInfo: [
                NSLocalizedDescriptionKey: "Für den konkreten Paketinhalt fehlt ein aktiver lokaler Freigabedatensatz."
            ])
        }
        var values = StudyExportManifest.Values()
        values.sessionID = input.projection.session.id
        values.operatingMode = input.projection.session.operatingMode
        values.provenance = input.provenance
        values.fileDigests = input.digests
        values.contentFiles = input.files.map(\.0)
        values.includedScopes = input.projection.requiredScopes
        let manifestURL = directory.appendingPathComponent("manifest.json")
        try StudyExportManifest(values).canonicalJSONData().write(to: manifestURL, options: .atomic)
        try applyTemporaryProtection(to: manifestURL)
    }

    private func discardPackage(_ destination: URL, fileManager: FileManager) async {
        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: destination)
        }
        _ = await leases.release(destination)
    }

    func removePackage(at packageURL: URL) async {
        guard await leases.release(packageURL) else { return }
        do {
            let fileManager = FileManager.default
            let root = try temporaryRoot(fileManager: fileManager)
            let candidate = packageURL.standardizedFileURL
            guard candidate.deletingLastPathComponent() == root.standardizedFileURL,
                  candidate.pathExtension == "videographrstudy"
            else { return }
            if fileManager.fileExists(atPath: candidate.path) {
                try fileManager.removeItem(at: candidate)
            }
        } catch {
            // The durable outbox remains authoritative; temporary cleanup is retried at startup.
        }
    }

    /// Mutation invalidation can remove stale packages, never a leased share item.
    func removeUnleasedPackages(for sessionID: UUID) async {
        do {
            let fileManager = FileManager.default
            let root = try temporaryRoot(fileManager: fileManager)
            let candidates = try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
                .filter { Self.packageSessionID(from: $0) == sessionID }
            for packageURL in await leases.unleasedPackages(in: candidates) {
                if fileManager.fileExists(atPath: packageURL.path) {
                    try fileManager.removeItem(at: packageURL)
                }
            }
        } catch {
            // Best-effort cleanup; startup performs a complete recognized-artifact sweep.
        }
    }

    /// No outbox attempt exists when construction or its pre-audit fails.
    func discardFailedPreparation(at packageURL: URL) async {
        await removePackage(at: packageURL)
    }

    private static func packageSessionID(from packageURL: URL) -> UUID? {
        guard packageURL.pathExtension == "videographrstudy" else { return nil }
        let stem = packageURL.deletingPathExtension().lastPathComponent
        // Accept the legacy session-only path as a stale artifact during rollout.
        if let legacyID = UUID(uuidString: stem) { return legacyID }
        let components = stem.components(separatedBy: "--")
        guard components.count == 2,
              UUID(uuidString: components[1]) != nil
        else { return nil }
        return UUID(uuidString: components[0])
    }

    func validatedManifest(at packageURL: URL, expectedSessionID: UUID) throws -> StudyExportManifest {
        let values = try packageURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true,
              packageURL.pathExtension == "videographrstudy"
        else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [
                NSLocalizedDescriptionKey: "Ungültiger Pakettyp."
            ])
        }
        let manifestURL = packageURL.appendingPathComponent("manifest.json", isDirectory: false)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(StudyExportManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.schemaVersion == StudyExportManifest.schemaVersion,
              manifest.sessionID == expectedSessionID
        else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [
                NSLocalizedDescriptionKey: "Paketmanifest und Sitzung stimmen nicht überein."
            ])
        }
        let fileData = try validatedContentFiles(in: packageURL)
        let failures = StudyPackageContract.validate(
            manifest: manifest,
            expectedSessionID: expectedSessionID,
            fileData: fileData
        )
        guard failures.isEmpty else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [
                NSLocalizedDescriptionKey: "Paketvalidierung fehlgeschlagen: \(failures.joined(separator: ", "))."
            ])
        }
        return manifest
    }

    private func validatedContentFiles(in packageURL: URL) throws -> [String: Data] {
        var fileData: [String: Data] = [:]
        for name in StudyPackageContract.expectedContentFiles {
            let fileURL = packageURL.appendingPathComponent(name, isDirectory: false)
            let values = try fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
            )
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  (values.fileSize ?? Int.max) <= StudyPackageContract.maximumContentFileBytes
            else { throw invalidPackageFile(name) }
            fileData[name] = try Data(contentsOf: fileURL)
        }
        return fileData
    }

    private func invalidPackageFile(_ name: String) -> CocoaError {
        CocoaError(.fileReadCorruptFile, userInfo: [
            NSLocalizedDescriptionKey: "Paketdatei \(name) ist nicht regulär."
        ])
    }

    private func canonicalData<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    private func jsonLines<T: Encodable>(_ values: [T]) throws -> Data {
        var output = Data()
        for value in values {
            output.append(try canonicalData(value))
            output.append(0x0a)
        }
        return output
    }

    private func removeStaleTemporaryPackages(in root: URL) throws {
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey, .isSymbolicLinkKey]) {
            let values = try url.resourceValues(forKeys: [.creationDateKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true,
                  (url.lastPathComponent.hasPrefix(".") && (url.pathExtension == "tmp" || url.pathExtension == "replacement")),
                  (values.creationDate ?? .distantPast) < cutoff
            else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func temporaryRoot(fileManager: FileManager) throws -> URL {
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("VideographrExports", isDirectory: true)
            .standardizedFileURL
        if (try? fileManager.destinationOfSymbolicLink(atPath: root.path)) != nil {
            throw CocoaError(.fileWriteInvalidFileName, userInfo: [
                NSLocalizedDescriptionKey: "Der temporäre Exportpfad darf kein symbolischer Link sein."
            ])
        }
        if fileManager.fileExists(atPath: root.path) {
            let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw CocoaError(.fileWriteInvalidFileName, userInfo: [
                    NSLocalizedDescriptionKey: "Der temporäre Exportpfad ist kein reguläres Verzeichnis."
                ])
            }
        } else {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    private func applyTemporaryProtection(to url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutableURL.setResourceValues(values)
        #if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
        #endif
    }
}
