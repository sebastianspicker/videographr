import ExperimentalResearch
import Foundation
import SessionCore
import XCTest

final class GaussianDepthSurfaceTests: XCTestCase {
    func testOriginalProjectionPreservesUVAndColorDespiteDepthVariation() throws {
        let surface = try fixture()
        let projected = GaussianProjection.project(surface, camera: GaussianCamera())
        XCTAssertEqual(projected.count, 4)
        for projectedPoint in projected {
            let point = projectedPoint.point
            XCTAssertEqual(abs(projectedPoint.x), 0.5, accuracy: 0.00001)
            XCTAssertEqual(abs(projectedPoint.y), 0.5, accuracy: 0.00001)
            XCTAssertEqual(point.red, 1)
            XCTAssertEqual(point.green, 64.0 / 255, accuracy: 0.00001)
            XCTAssertEqual(point.blue, 0)
            XCTAssertTrue((0.8...1.5).contains(point.z))
        }
        XCTAssertEqual(projected.map(\.cameraDepth), projected.map(\.cameraDepth).sorted(by: >))
    }

    func testLateralPerspectiveMovesNearPointsMoreThanFarPoints() throws {
        let surface = try fixture()
        let original = GaussianProjection.project(surface, camera: GaussianCamera())
        let changed = GaussianProjection.project(surface, camera: GaussianCamera(horizontal: 0.04))
        let farShift = original[0].x - changed[0].x
        let nearShift = original[3].x - changed[3].x
        XCTAssertGreaterThan(nearShift, farShift)
        XCTAssertGreaterThan(farShift, 0)
    }

    func testCameraBoundsRejectNonFiniteAndExcessiveMovement() {
        let camera = GaussianCamera(horizontal: 12, vertical: -12, dolly: .nan)
        XCTAssertEqual(camera.horizontal, GaussianCamera.lateralLimit)
        XCTAssertEqual(camera.vertical, -GaussianCamera.lateralLimit)
        XCTAssertEqual(camera.dolly, 0)
        XCTAssertEqual(GaussianCamera(dolly: 8).dolly, GaussianCamera.dollyLimit)
        let orbit = GaussianCamera(yawDegrees: 90, pitchDegrees: -90)
        XCTAssertEqual(orbit.yawDegrees, GaussianCamera.yawLimitDegrees)
        XCTAssertEqual(orbit.pitchDegrees, -GaussianCamera.pitchLimitDegrees)
        XCTAssertEqual(GaussianCamera(yawDegrees: .nan, pitchDegrees: .infinity), GaussianCamera())
    }

    func testOrbitKeepsDisplayFocusCenteredAndSortsTransformedDepth() throws {
        let surface = try GaussianDepthSurface.make(
            width: 3, height: 3, rgba: Array(repeating: 255, count: 36),
            inverseDepth: [0, 0, 0, 0, 1, 2, 2, 2, 2], aspectRatio: 1
        )
        for yaw in [Float(-5), 0, 5] {
            for pitch in [Float(-4), 0, 4] {
                let projected = GaussianProjection.project(surface, camera: GaussianCamera(
                    dolly: 0.04, yawDegrees: yaw, pitchDegrees: pitch
                ))
                let focus = try XCTUnwrap(projected.first { abs($0.point.x) < 0.00001 && abs($0.point.y) < 0.00001 })
                XCTAssertEqual(focus.x, 0, accuracy: 0.00001)
                XCTAssertEqual(focus.y, 0, accuracy: 0.00001)
                XCTAssertEqual(focus.cameraDepth, GaussianCamera.focusDepth - 0.04, accuracy: 0.00001)
                XCTAssertEqual(projected.map(\.cameraDepth), projected.map(\.cameraDepth).sorted(by: >))
                XCTAssertTrue(projected.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.sigmaX > 0 && $0.sigmaY > 0 })
            }
        }
    }

    func testDepthIsAffineInInverseDepthAndClampedToRobustRange() throws {
        // Percentiles of [0, 1, 2, 3] are 0 and 2, so normalized disparity is 0, 0.5, 1, 1.
        let depths = try fixture().points.map(\.z)
        let near = GaussianDepthSurface.nearestDepth, far = GaussianDepthSurface.farthestDepth
        XCTAssertEqual(depths[0], far)
        XCTAssertEqual(1 / depths[1], (1 / near + 1 / far) / 2, accuracy: 0.00001)
        XCTAssertEqual(depths[2], near)
        XCTAssertEqual(depths[3], near)
    }

    func testDisparityJumpShrinksFootprintsOnBothSides() throws {
        let surface = try GaussianDepthSurface.make(
            width: 4, height: 2, rgba: Array(repeating: 255, count: 32),
            inverseDepth: [0, 0, 1, 1, 0, 0, 1, 1], aspectRatio: 2
        )
        let scale = surface.points.map { $0.sigma / $0.z }
        XCTAssertEqual(scale[1], scale[0] * 0.65, accuracy: 0.000001)
        XCTAssertEqual(scale[2], scale[0] * 0.65, accuracy: 0.000001)
        XCTAssertEqual(scale[3], scale[0], accuracy: 0.000001)
    }

    func testSourceViewFootprintMatchesTextureFootprintOnTiltedSurface() throws {
        let surface = try ramp()
        let projected = GaussianProjection.project(surface, camera: GaussianCamera())
        XCTAssertEqual(projected.count, 80 * 60)
        for projectedPoint in projected {
            let point = projectedPoint.point
            // The tilt only adds a component along the source ray, which projects to nothing,
            // so each texture lookup lands on the source pixel under it.
            XCTAssertEqual(projectedPoint.axisU.x, 2 * point.textureStep.x, accuracy: 0.00001)
            XCTAssertEqual(projectedPoint.axisU.y, 0, accuracy: 0.00001)
            XCTAssertEqual(projectedPoint.axisV.x, 0, accuracy: 0.00001)
            XCTAssertEqual(projectedPoint.axisV.y, -2 * point.textureStep.y, accuracy: 0.00001)
            XCTAssertEqual(projectedPoint.x, 2 * point.textureCenter.x - 1, accuracy: 0.00001)
            XCTAssertEqual(projectedPoint.y, 1 - 2 * point.textureCenter.y, accuracy: 0.00001)
        }
        XCTAssertGreaterThan(surface.points.filter { $0.tangentV.z != 0 }.count, 4000)
        let corner = surface.points[81]
        XCTAssertEqual(corner.textureCenter, SIMD2(1.5 / 80, 1.5 / 60))
        let steps = GaussianDepthSurface.footprintSteps
        XCTAssertEqual(corner.textureStep, SIMD2(steps / 80, steps / 60))
    }

    func testSurfelsKeepCoveringTiltedSurfaceAfterViewChange() throws {
        let surface = try ramp()
        func positions(_ camera: GaussianCamera) -> [SIMD2<Float>: GaussianProjectedPoint] {
            Dictionary(uniqueKeysWithValues: GaussianProjection.project(surface, camera: camera).map {
                ($0.point.textureCenter, $0)
            })
        }
        let original = positions(GaussianCamera())
        let moved = positions(GaussianCamera(vertical: 0.1, dolly: 0.08, yawDegrees: 3, pitchDegrees: 4))
        func length(_ vector: SIMD2<Float>) -> Float { (vector * vector).sum().squareRoot() }
        var largestStretch: Float = 0
        var checked = 0
        // Rows 6...53 lie inside the robust disparity range, so the ramp is smooth there.
        for row in 6...53 {
            for column in 1...78 {
                let center = surface.points[row * 80 + column].textureCenter
                let above = surface.points[(row - 1) * 80 + column].textureCenter
                let below = surface.points[(row + 1) * 80 + column].textureCenter
                // Points that leave the moved view are culled.
                guard let point = moved[center], let up = moved[above], let down = moved[below] else { continue }
                checked += 1
                // One grid step of the moved surface is covered by one footprint step.
                let neighbours = (SIMD2(down.x, down.y) - SIMD2(up.x, up.y)) / 2
                let footprint = point.axisV / GaussianDepthSurface.footprintSteps
                XCTAssertLessThan(length(neighbours - footprint), 0.02 * length(neighbours))
                let source = try XCTUnwrap(original[center])
                let sourceStep = length(source.axisV / GaussianDepthSurface.footprintSteps)
                largestStretch = max(largestStretch, abs(length(neighbours) / sourceStep - 1))
            }
        }
        XCTAssertGreaterThan(checked, 3000)
        // A fronto-parallel footprint would leave visible gaps or overlaps of this size.
        XCTAssertGreaterThan(largestStretch, 0.08)
    }

    func testOcclusionEdgesUseOneSidedSlopesAndNeverBridgeTheJump() throws {
        // Normalized disparity per row is 0, 0.05, 0.1, 1, 1, 1.
        let row: [Float] = [0, 0.1, 0.2, 2, 2, 2]
        let surface = try GaussianDepthSurface.make(
            width: 6, height: 2, rgba: Array(repeating: 255, count: 48),
            inverseDepth: row + row, aspectRatio: 1
        )
        let points = surface.points
        let steps = GaussianDepthSurface.footprintSteps
        XCTAssertEqual(points[1].tangentU.z, steps * (points[2].z - points[0].z) / 2, accuracy: 0.000001)
        XCTAssertEqual(points[2].tangentU.z, steps * 0.65 * (points[2].z - points[1].z), accuracy: 0.000001)
        XCTAssertEqual(points[3].tangentU.z, 0, accuracy: 0.000001)
        XCTAssertEqual(points[2].textureStep.x, steps * 0.65 / 6, accuracy: 0.000001)
        XCTAssertEqual(points[1].textureStep.x, steps / 6, accuracy: 0.000001)
        XCTAssertTrue(points.allSatisfy { $0.tangentV.z == 0 })
    }

    func testSourceViewStretchIsOneAndFrontoParallelDollyStaysBelowOnset() throws {
        let projected = GaussianProjection.project(try ramp(), camera: GaussianCamera())
        XCTAssertEqual(projected.count, 80 * 60)
        for point in projected {
            XCTAssertEqual(point.stretch, 1, accuracy: 0.001)
        }
        // Rows 0-3 and 36-39 pin the robust range; the middle plane is fronto-parallel.
        let plane = try GaussianDepthSurface.make(
            width: 40, height: 40, rgba: Array(repeating: 255, count: 40 * 40 * 4),
            inverseDepth: (0..<40).flatMap { row in
                Array(repeating: Float(row < 4 ? 0 : row >= 36 ? 1 : 0.5), count: 40)
            },
            aspectRatio: 1
        )
        let dolly = GaussianCamera.dollyLimit
        var checked = 0
        for point in GaussianProjection.project(plane, camera: GaussianCamera(dolly: dolly))
        where !point.point.isOcclusionEdge {
            let expected = pow(point.point.z / (point.point.z - dolly), 2)
            XCTAssertEqual(point.stretch, expected, accuracy: 0.001)
            XCTAssertLessThan(point.stretch, GaussianEvidence.stretchOnset)
            checked += 1
        }
        XCTAssertGreaterThan(checked, 1000)
    }

    func testObliqueViewStretchesTiltedSurfaceBeyondOnset() throws {
        let projected = GaussianProjection.project(
            try ramp(), camera: GaussianCamera(dolly: 0.08, yawDegrees: 5, pitchDegrees: 4)
        )
        XCTAssertTrue(projected.contains { $0.stretch > GaussianEvidence.stretchOnset })
    }

    func testEvidenceUncertaintyIsBoundedMonotoneAndFlagsOcclusionEdges() {
        XCTAssertEqual(GaussianEvidence.uncertainty(stretch: 1, isOcclusionEdge: false), 0)
        XCTAssertEqual(GaussianEvidence.uncertainty(stretch: 1, isOcclusionEdge: true), 0.5)
        XCTAssertEqual(GaussianEvidence.uncertainty(stretch: 3, isOcclusionEdge: false), 1)
        XCTAssertEqual(GaussianEvidence.uncertainty(stretch: .nan, isOcclusionEdge: false), 1)
        XCTAssertEqual(GaussianEvidence.uncertainty(stretch: .infinity, isOcclusionEdge: false), 1)
        for edge in [false, true] {
            var previous: Float = 0
            for step in 0...80 {
                let value = GaussianEvidence.uncertainty(stretch: Float(step) / 16, isOcclusionEdge: edge)
                XCTAssertGreaterThanOrEqual(value, previous)
                XCTAssertTrue((0...1).contains(value))
                previous = value
            }
        }
    }

    func testOcclusionEdgeFlagMarksBothSidesOfDisparityJump() throws {
        let row: [Float] = [0, 0.1, 0.2, 2, 2, 2]
        let surface = try GaussianDepthSurface.make(
            width: 6, height: 2, rgba: Array(repeating: 255, count: 48),
            inverseDepth: row + row, aspectRatio: 1
        )
        XCTAssertEqual(surface.points.map(\.isOcclusionEdge),
                       [false, false, true, true, false, false, false, false, true, true, false, false])
    }

    func testDrawOrderMatchesReferenceProjectionAndIsUniqueAfterReuse() throws {
        let surface = try GaussianDepthSurface.make(
            width: 4, height: 3, rgba: Array(repeating: 255, count: 48),
            inverseDepth: [0, 0, 0, 0, 1, 2, 3, 3, 3, 3, 1, 0], aspectRatio: 1.5
        )
        let original = GaussianViewFrame(camera: GaussianCamera()).forward
        let fresh = GaussianProjection.drawOrder(surface, forward: original)
        for camera in [GaussianCamera(), GaussianCamera(horizontal: 0.1, vertical: -0.1, dolly: 0.08),
                       GaussianCamera(yawDegrees: 5, pitchDegrees: -4), GaussianCamera(dolly: -0.08, yawDegrees: -5)] {
            let frame = GaussianViewFrame(camera: camera)
            let order = GaussianProjection.drawOrder(surface, forward: frame.forward, reusing: fresh)
            XCTAssertEqual(order, GaussianProjection.drawOrder(surface, forward: frame.forward))
            let depths = order.map { index -> Float in
                let point = surface.points[Int(index)]
                return ((SIMD3(point.x, point.y, point.z) - frame.position) * frame.forward).sum()
            }
            let reference = GaussianProjection.project(surface, camera: camera).map(\.cameraDepth)
            XCTAssertEqual(depths.count, reference.count)
            for (depth, expected) in zip(depths, reference) { XCTAssertEqual(depth, expected, accuracy: 0.00001) }
        }
        // Translation never changes the orientation, so the renderer keeps its order.
        XCTAssertEqual(GaussianViewFrame(camera: GaussianCamera(horizontal: 0.1, dolly: 0.08)).forward, original)
        let orbit = GaussianProjection.drawOrder(
            surface, forward: GaussianViewFrame(camera: GaussianCamera(yawDegrees: 5)).forward, reusing: fresh
        )
        XCTAssertEqual(GaussianProjection.drawOrder(surface, forward: original, reusing: orbit), fresh)
    }

    func testDrawOrderHandlesNegativeAndSignedZeroKeys() throws {
        // x is -3a, -a, a, 3a per row; looking down -x sorts large x first, ties by index.
        let surface = try GaussianDepthSurface.make(
            width: 4, height: 2, rgba: Array(repeating: 255, count: 32),
            inverseDepth: Array(repeating: 0, count: 4) + Array(repeating: 1, count: 4), aspectRatio: 1
        )
        let order = GaussianProjection.drawOrder(surface, forward: SIMD3(-1, 0, 0), reusing: [0])
        let keys = order.map { -surface.points[Int($0)].x }
        XCTAssertEqual(keys, keys.sorted(by: >))
        XCTAssertEqual(Set(order).count, surface.points.count)
        // A zero direction gives every point a -0 or +0 key; both must tie and keep index order.
        XCTAssertEqual(GaussianProjection.drawOrder(surface, forward: SIMD3(-0.0, 0, 0)), Array(0..<8))
    }

    func testMalformedOrUnusableDepthHasNoSuccessfulFallback() {
        XCTAssertThrowsError(try GaussianDepthSurface.make(width: 0, height: 4, rgba: [], inverseDepth: [], aspectRatio: 1))
        XCTAssertThrowsError(try GaussianDepthSurface.make(width: 200, height: 200, rgba: [], inverseDepth: [], aspectRatio: 1))
        XCTAssertThrowsError(try fixture(depths: [0, 1, .infinity, 2]))
        XCTAssertThrowsError(try fixture(depths: [1, 1, 1, 1]))
        XCTAssertThrowsError(try fixture(depths: [-1, 1, 2, 3]))
        XCTAssertThrowsError(try GaussianDepthSurface.make(width: 2, height: 2, rgba: [], inverseDepth: [0, 1, 2, 3], aspectRatio: 1))
    }

    func testPerspectiveAuthorizationRequiresBothScopesModeAndCurrentProtocol() {
        let now = Date(timeIntervalSince1970: 100)
        var values = CaptureSession.Values()
        values.operatingMode = .experimentalResearch
        values.experimentalProtocol = ResearchProtocolReference(
            protocolIdentifier: "synthetic", oversightReference: "test",
            expiresAt: now.addingTimeInterval(10), disclosureAcknowledgedAt: now
        )
        var grant = ConsentGrant.Values()
        grant.scopes = [.researchProcessing, .localReflection]
        grant.grantedAt = now
        grant.expiresAt = now.addingTimeInterval(5)
        grant.documentIdentifier = "synthetic-test"
        grant.documentVersion = "1"
        grant.participantGroupPseudonym = "synthetic-group"
        values.consentGrants = [ConsentGrant(grant)]
        var session = CaptureSession(values)
        XCTAssertTrue(GaussianExplorationPolicy.permits(session, at: now))
        XCTAssertFalse(GaussianExplorationPolicy.permits(session, at: now.addingTimeInterval(5)))
        session.operatingMode = .evidenceSafe
        XCTAssertFalse(GaussianExplorationPolicy.permits(session, at: now))
        session.operatingMode = .experimentalResearch
        session.consentGrants[0].scopes = [.researchProcessing]
        XCTAssertFalse(GaussianExplorationPolicy.permits(session, at: now))
        session.consentGrants[0].scopes = [.localReflection]
        XCTAssertFalse(GaussianExplorationPolicy.permits(session, at: now))
        session.consentGrants = values.consentGrants
        session.experimentalProtocol?.expiresAt = now
        XCTAssertFalse(GaussianExplorationPolicy.permits(session, at: now))
    }

    private func fixture(depths: [Float] = [0, 1, 2, 3]) throws -> GaussianDepthSurface {
        try GaussianDepthSurface.make(
            width: 2, height: 2,
            rgba: Array(repeating: [UInt8(255), 64, 0, 255], count: 4).flatMap { $0 },
            inverseDepth: depths, aspectRatio: 2
        )
    }

    /// A floor-like surface that recedes towards the top, fine enough to stay below the footprint clamp.
    private func ramp() throws -> GaussianDepthSurface {
        try GaussianDepthSurface.make(
            width: 80, height: 60, rgba: Array(repeating: 255, count: 80 * 60 * 4),
            inverseDepth: (0..<60).flatMap { row in Array(repeating: Float(row), count: 80) },
            aspectRatio: 4 / 3
        )
    }

    func testFrozenAuthorizationIgnoresNotesButRejectsProtocolOrGrantReplacement() {
        var session = CaptureSession(CaptureSession.Values())
        let original = GaussianAuthorizationContext(session: session)
        session.title = "Unrelated reflection context"
        XCTAssertTrue(original.matches(session))
        session.operatingMode = .experimentalResearch
        XCTAssertFalse(original.matches(session))
        let modeSnapshot = GaussianAuthorizationContext(session: session)
        session.experimentalProtocol = ResearchProtocolReference(
            protocolIdentifier: "synthetic", oversightReference: "test",
            expiresAt: Date().addingTimeInterval(60), disclosureAcknowledgedAt: Date()
        )
        XCTAssertFalse(modeSnapshot.matches(session))
        let protocolSnapshot = GaussianAuthorizationContext(session: session)
        session.consentGrants = [ConsentGrant(ConsentGrant.Values())]
        XCTAssertFalse(protocolSnapshot.matches(session))
    }
}
