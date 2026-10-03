import Foundation

/// Filesystem access for `.videographrstudy` package directories; the pure contract lives in `StudyPackageContract`.
public enum StudyPackageDirectory: Sendable {
    /// Enumerates direct package members once and rejects any member that is not a regular file.
    /// Call this before reading package bytes so extra files, links, and directories cannot be ignored.
    public static func validatedMemberURLs(in packageURL: URL) throws -> [String: URL] {
        let fileManager = FileManager.default
        let packageValues = try packageURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard packageValues.isDirectory == true, packageValues.isSymbolicLink != true,
              (try? fileManager.destinationOfSymbolicLink(atPath: packageURL.path)) == nil
        else { throw StudyPackageFilesystemError.invalidPackageRoot }

        let memberURLs = try fileManager.contentsOfDirectory(
            at: packageURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsSubdirectoryDescendants]
        )
        var membersByName: [String: URL] = [:]
        for memberURL in memberURLs {
            let values = try memberURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  (try? fileManager.destinationOfSymbolicLink(atPath: memberURL.path)) == nil
            else { throw StudyPackageFilesystemError.invalidMember(memberURL.lastPathComponent) }
            membersByName[memberURL.lastPathComponent] = memberURL
        }
        guard Set(membersByName.keys) == Set(StudyPackageContract.expectedPackageFiles),
              membersByName.count == StudyPackageContract.expectedPackageFiles.count
        else { throw StudyPackageFilesystemError.unexpectedMembers }
        return membersByName
    }
}
