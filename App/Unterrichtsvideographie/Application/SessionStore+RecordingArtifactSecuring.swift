import Foundation
import SessionCore

/// `SessionStore` already exposes the exact secure/discard operations the capture owner needs.
extension SessionStore: RecordingArtifactSecuring {}
