import AVFoundation
import ExperimentalResearch
import Foundation
import SessionCore

@MainActor private final class AuthorizationBox { var permits = true }

@main enum LaunchSmoke {
    @MainActor static func main() async throws {
        let now = Date()
        var values = CaptureSession.Values()
        values.operatingMode = .experimentalResearch
        values.experimentalProtocol = ResearchProtocolReference(
            protocolIdentifier: "synthetic", oversightReference: "test",
            expiresAt: now.addingTimeInterval(600), disclosureAcknowledgedAt: now)
        var grant = ConsentGrant.Values()
        grant.scopes = [.localReflection, .researchProcessing]
        grant.grantedAt = now
        grant.documentIdentifier = "synthetic"
        grant.documentVersion = "1"
        grant.participantGroupPseudonym = "fixture"
        values.consentGrants = [ConsentGrant(grant)]
        var asset = SessionMediaAsset.Values()
        asset.relativePath = "synthetic.mp4"
        let media = SessionMediaAsset(asset)
        values.mediaAssets = [media]
        let session = CaptureSession(values)
        let selection = GaussianLaunchPreparation.Selection(session: session, assetID: media.id,
            mediaURL: URL(fileURLWithPath: "/synthetic-not-read.mp4"))
        var order: [String] = []
        let request = try await GaussianLaunchPreparation.prepare(selection: selection,
            persist: { order.append("persist"); return true },
            currentSelection: { order.append("validate"); return selection },
            freeze: { order.append("freeze"); return CMTime(value: 12, timescale: 30) })
        precondition(order == ["persist", "validate", "freeze"])
        precondition(request.authorization?.matches(session) == true)
        var frozen = false
        do {
            _ = try await GaussianLaunchPreparation.prepare(selection: selection,
                persist: { false }, currentSelection: { selection },
                freeze: { frozen = true; return .zero })
            fatalError("Failed persistence accepted")
        } catch GaussianFrameError.persistenceUnavailable { }
        precondition(!frozen)
        do {
            _ = try await GaussianLaunchPreparation.prepare(selection: selection,
                persist: { true }, currentSelection: { nil },
                freeze: { frozen = true; return .zero })
            fatalError("Stale selection accepted")
        } catch GaussianFrameError.staleRequest { }
        precondition(!frozen)
        do {
            _ = try await GaussianFrameGenerator.generate(request, modelURL: nil)
            fatalError("Missing model accepted")
        } catch GaussianFrameError.modelUnavailable { }
        let nonexistentModel = URL(fileURLWithPath: "/synthetic-not-read.mlpackage")
        do {
            _ = try await GaussianFrameGenerator.generate(request, modelURL: nonexistentModel,
                isAuthorized: { false })
            fatalError("Unauthorized generation accepted")
        } catch is CancellationError { }
        let authorization = AuthorizationBox()
        do {
            _ = try await GaussianFrameGenerator.generate(request, modelURL: nonexistentModel,
                isAuthorized: { authorization.permits },
                onProgress: { stage in
                    if stage == .extractingFrame {
                        await MainActor.run { authorization.permits = false }
                    }
                })
            fatalError("Authority revoked during extraction progress accepted")
        } catch is CancellationError { }
        print("PASS: authorization denial and revocation checked before native frame access")
        print("PASS: persisted launch ordering, failed/stale launch refuses freeze, missing model error")
    }
}
