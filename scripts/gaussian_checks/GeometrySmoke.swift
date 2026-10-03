import ExperimentalResearch
import Foundation
import SessionCore

func surface(_ values: [Float] = [0, 1, 2, 3]) throws -> GaussianDepthSurface {
    try GaussianDepthSurface.make(width: 2, height: 2,
        rgba: Array(repeating: [UInt8(255), 64, 0, 255], count: 4).flatMap { $0 },
        inverseDepth: values, aspectRatio: 2)
}
let scene = try surface()
let original = GaussianProjection.project(scene, camera: GaussianCamera())
let shifted = GaussianProjection.project(scene, camera: GaussianCamera(horizontal: 0.04))
precondition(original.count == 4 && shifted.count == 4)
for point in original {
    precondition(abs(abs(point.x) - 0.5) < 0.00001)
    precondition(abs(abs(point.y) - 0.5) < 0.00001)
    precondition(point.point.red == 1 && point.point.blue == 0)
    precondition((0.8...1.5).contains(point.cameraDepth))
}
precondition(original.map(\.cameraDepth) == original.map(\.cameraDepth).sorted(by: >))
precondition(original[3].x - shifted[3].x > original[0].x - shifted[0].x)
let bounded = GaussianCamera(horizontal: .infinity, vertical: -99, dolly: 99)
precondition(bounded.horizontal == 0 && bounded.vertical == -GaussianCamera.lateralLimit)
precondition(bounded.dolly == GaussianCamera.dollyLimit)
for invalid: [Float] in [[1, 1, 1, 1], [-1, 0, 1, 2], [0, .nan, 1, 2], [0, .infinity, 1, 2], []] {
    do { _ = try surface(invalid); fatalError("Accepted invalid depth") } catch { }
}
do {
    _ = try GaussianDepthSurface.make(width: Int.max, height: Int.max, rgba: [], inverseDepth: [], aspectRatio: 1)
    fatalError("Accepted unbounded dimensions")
} catch { }
let now = Date(timeIntervalSince1970: 100)
var values = CaptureSession.Values()
values.operatingMode = .experimentalResearch
values.experimentalProtocol = ResearchProtocolReference(protocolIdentifier: "synthetic", oversightReference: "test", expiresAt: now.addingTimeInterval(10), disclosureAcknowledgedAt: now)
var grant = ConsentGrant.Values()
grant.scopes = [.localReflection, .researchProcessing]
grant.grantedAt = now
grant.expiresAt = now.addingTimeInterval(5)
grant.documentIdentifier = "synthetic"
grant.documentVersion = "1"
grant.participantGroupPseudonym = "fixture"
values.consentGrants = [ConsentGrant(grant)]
var session = CaptureSession(values)
precondition(GaussianExplorationPolicy.permits(session, at: now))
precondition(!GaussianExplorationPolicy.permits(session, at: now.addingTimeInterval(5)))
session.operatingMode = .evidenceSafe
precondition(!GaussianExplorationPolicy.permits(session, at: now))
session.operatingMode = .experimentalResearch
session.consentGrants[0].scopes = [.researchProcessing]
precondition(!GaussianExplorationPolicy.permits(session, at: now))
print("PASS: source projection, perspective parallax, depth ordering, camera bounds, invalid input rejection, consent/mode/expiry")

let orbit = GaussianCamera(yawDegrees: 99, pitchDegrees: -99)
precondition(orbit.yawDegrees == GaussianCamera.yawLimitDegrees)
precondition(orbit.pitchDegrees == -GaussianCamera.pitchLimitDegrees)
let orbitPoints = GaussianProjection.project(scene, camera: orbit)
precondition(!orbitPoints.isEmpty && orbitPoints.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.cameraDepth > 0 })
precondition(orbitPoints.map(\.cameraDepth) == orbitPoints.map(\.cameraDepth).sorted(by: >))
precondition(GaussianProjection.project(scene, camera: GaussianCamera()) == original)
let authorization = GaussianAuthorizationContext(session: session)
precondition(authorization.matches(session))
session.title = "Changed reflection title"
precondition(authorization.matches(session))
session.consentGrants[0].participantGroupPseudonym = "replaced-group"
precondition(!authorization.matches(session))
print("PASS: bounded orbit, finite projection, reset and frozen authorization identity")

let orbitSurface = try GaussianDepthSurface.make(width: 3, height: 3,
    rgba: Array(repeating: 255, count: 36), inverseDepth: [0, 0, 0, 0, 1, 2, 2, 2, 2], aspectRatio: 1)
for yaw in [Float(-5), 0, 5] {
    for pitch in [Float(-4), 0, 4] {
        let projected = GaussianProjection.project(orbitSurface, camera: GaussianCamera(dolly: 0.04, yawDegrees: yaw, pitchDegrees: pitch))
        let focus = projected.first { abs($0.point.x) < 0.00001 && abs($0.point.y) < 0.00001 }!
        precondition(abs(focus.x) < 0.00001 && abs(focus.y) < 0.00001)
        precondition(abs(focus.cameraDepth - (GaussianCamera.focusDepth - 0.04)) < 0.00001)
        precondition(projected.map(\.cameraDepth) == projected.map(\.cameraDepth).sorted(by: >))
        precondition(projected.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.sigmaX > 0 && $0.sigmaY > 0 })
    }
}
let left = GaussianProjection.project(orbitSurface, camera: GaussianCamera(yawDegrees: -5))
let right = GaussianProjection.project(orbitSurface, camera: GaussianCamera(yawDegrees: 5))
let a = left.first { $0.point.x < 0 && $0.point.y > 0 }!
let b = right.first { $0.point.x > 0 && $0.point.y > 0 }!
precondition(abs(a.x + b.x) < 0.00001 && abs(a.y - b.y) < 0.00001)
precondition(GaussianCamera(yawDegrees: .nan, pitchDegrees: .infinity) == GaussianCamera())
print("PASS: bounded orbit, invariant focus, symmetric views, finite footprints and transformed depth ordering")
