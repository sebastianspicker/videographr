import ExperimentalResearch
import Foundation
import GuidanceEngine
import SessionCore

/// The one place that composes build identity and algorithm versions into persisted provenance.
enum BuildProvenanceFactory {
    static func captureAlgorithmVersion(for mode: OperatingMode) -> String {
        mode == .experimentalResearch
            ? CaptureAlgorithmVersion.directObservability + "+" + ExperimentalAlgorithmVersion.suffix
            : CaptureAlgorithmVersion.directObservability
    }

    static func capture(for mode: OperatingMode) -> BuildProvenance {
        make(algorithmVersion: captureAlgorithmVersion(for: mode))
    }

    static var export: BuildProvenance {
        make(algorithmVersion: CaptureAlgorithmVersion.studyPackage)
    }

    /// Provenance stamped on experimental coding snapshots produced during live capture.
    static var researchArtifact: ResearchArtifactProvenance {
        ResearchArtifactProvenance((
            semanticVersion: BuildIdentity.current.semanticVersion,
            buildNumber: BuildIdentity.current.buildNumber,
            schemaVersion: SessionSchema.currentVersion,
            algorithmVersion: captureAlgorithmVersion(for: .experimentalResearch),
            evidenceRegistryVersion: String(EvidenceClaimRegistry.version)
        ))
    }

    private static func make(algorithmVersion: String) -> BuildProvenance {
        var values = BuildProvenance.Values()
        values.semanticVersion = BuildIdentity.current.semanticVersion
        values.buildNumber = BuildIdentity.current.buildNumber
        values.algorithmVersion = algorithmVersion
        values.evidenceRegistryVersion = String(EvidenceClaimRegistry.version)
        return BuildProvenance(values)
    }
}
