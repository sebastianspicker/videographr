import XCTest
@testable import GuidanceEngine

extension CVAndMetricsTests {
    func testFuseBoardEdgeSupportPrefersMultiCueCorroboration() {
        let weak = CVFeatureFusion.fuseBoardEdgeSupport(
            documentOverlap: 0,
            saliencyOverlap: 0,
            textSupport: 0,
            geometryFallback: 0.2
        )
        let strong = CVFeatureFusion.fuseBoardEdgeSupport(
            documentOverlap: 0.8,
            saliencyOverlap: 0.6,
            textSupport: 0.7,
            geometryFallback: 0.2
        )
        XCTAssertGreaterThan(strong, weak)
        XCTAssertGreaterThan(strong, 0.55)
        XCTAssertLessThan(weak, 0.35)
    }

    func testJointPointMidBandAndCentroid() {
        let midJoints: [(x: Double, y: Double)] = [(0.4, 0.5), (0.55, 0.55), (0.48, 0.48)]
        let floorJoints: [(x: Double, y: Double)] = [(0.2, 0.92), (0.3, 0.95)]
        XCTAssertGreaterThan(
            CVFeatureFusion.midBandOccupancy(jointPoints: midJoints),
            CVFeatureFusion.midBandOccupancy(jointPoints: floorJoints)
        )
        guard let centroid = CVFeatureFusion.peopleCentroid(jointPoints: midJoints) else {
            return XCTFail("Expected joint centroid")
        }
        XCTAssertEqual(centroid.y, 0.51, accuracy: 0.05)
    }
}
