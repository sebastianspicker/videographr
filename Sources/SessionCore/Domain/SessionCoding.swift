import CryptoKit
import Foundation

/// One named home for every persisted or exported byte format's codec settings.
/// Changing any setting here changes bytes on disk or in study packages; the
/// `PersistedFormatContractTests` freeze the results.
public enum SessionCoding: Sendable {
    /// `session.json` files: pretty-printed, sorted keys, ISO-8601 dates.
    public static func sessionFileEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// One JSONL line of an append-only journal: compact, sorted keys, ISO-8601 dates.
    public static func journalLineEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// Canonical JSON for manifests, integrity details, and study-package JSONL lines:
    /// compact, sorted keys, ISO-8601 dates.
    public static func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// Decoder for every format above (all dates are ISO-8601).
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Consent scopes in canonical (raw-value) order. Synthesized `Set` encoding follows the
    /// per-process hash seed, so persisted scope sets must be encoded through this order.
    public static func canonicalOrder(_ scopes: Set<ConsentScope>) -> [ConsentScope] {
        scopes.sorted { $0.rawValue < $1.rawValue }
    }

    /// Lowercase hexadecimal SHA-256 digest of in-memory data.
    public static func sha256Hex(_ data: Data) -> String {
        hex(SHA256.hash(data: data))
    }

    /// Lowercase hexadecimal rendering of a SHA-256 digest, including streamed digests.
    public static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
