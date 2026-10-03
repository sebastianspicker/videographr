import Foundation
import GuidanceEngine

// MARK: - Classroom spatial layout (research structure CV)

/// Spatial arrangement of actors in the frame - beyond placement geometry.
///
/// Research capture (TIMSS scripts; IPN process quality; Kramer production): scene structure
/// (rows, dyads, clusters, circle, seatwork scatter) must match the selected teaching situation.
/// Pure layout metrics derived from person geometry (and optional board).
public struct ClassroomLayoutMetrics: Equatable, Sendable {
    public struct Values: Sendable {
        public var horizontalSpread = 0.0
        public var verticalSpread = 0.0
        public var clusteredness = 0.0
        public var estimatedClusterCount = 0
        public var meanPairwiseDistance = 0.0
        public var pattern = ClassroomLayoutPattern.unknown
        public var faceScaleScore = 0.0

        public init() {}
    }

    /// Horizontal spread of person centroids (0…1, higher = more laterally distributed).
    public var horizontalSpread: Double
    /// Vertical spread of person centroids (0…1).
    public var verticalSpread: Double
    /// How tightly people cluster (0 = fully spread, 1 = single tight cluster).
    public var clusteredness: Double
    /// Estimated number of spatial clusters (greedy distance clustering).
    public var estimatedClusterCount: Int
    /// Mean pairwise distance between person centers (normalized).
    public var meanPairwiseDistance: Double
    /// Classified layout pattern.
    public var pattern: ClassroomLayoutPattern
    /// Average face/person scale as proximity proxy (larger = closer shot). 0…1
    public var faceScaleScore: Double

    public init(_ values: Values = Values()) {
        self.horizontalSpread = min(1, max(0, values.horizontalSpread))
        self.verticalSpread = min(1, max(0, values.verticalSpread))
        self.clusteredness = min(1, max(0, values.clusteredness))
        self.estimatedClusterCount = max(0, values.estimatedClusterCount)
        self.meanPairwiseDistance = min(1, max(0, values.meanPairwiseDistance))
        self.pattern = values.pattern
        self.faceScaleScore = min(1, max(0, values.faceScaleScore))
    }

    public static let empty: ClassroomLayoutMetrics = {
        var values = Values()
        values.pattern = .empty
        return ClassroomLayoutMetrics(values)
    }()
}

/// Pure layout analysis from person/board geometry (no Vision dependency).
public struct ClassroomLayoutAnalysisInput: Sendable {
    public var personRects: [ImageNormalizedRect]
    public var board: ImageNormalizedRect?
    public var boardConfidence = 0.0
    public var faceCount = 0
    public var personCount = 0

    public init(personRects: [ImageNormalizedRect]) {
        self.personRects = personRects
    }
}

public enum ClassroomLayoutAnalyzer: Sendable {

    /// Analyze layout from person rectangles (top-left normalized) and optional board.
    public static func analyze(_ input: ClassroomLayoutAnalysisInput) -> ClassroomLayoutMetrics {
        let n = resolvedPersonCount(
            personRects: input.personRects,
            faceCount: input.faceCount,
            personCount: input.personCount
        )
        if n == 0 && input.personRects.isEmpty {
            return .empty
        }

        let centers = input.personRects.map {
            (x: $0.centerX, y: $0.centerY, area: max(1e-9, $0.area))
        }

        if centers.isEmpty {
            // Count-only fallback: weak layout prior from counts alone.
            return countOnlyLayout(peopleN: n, boardConfidence: input.boardConfidence)
        }

        let hSpread = ClassroomLayoutGeometry.spread(centers.map(\.x))
        let vSpread = ClassroomLayoutGeometry.spread(centers.map(\.y))
        let pairwise = ClassroomLayoutGeometry.meanPairwise(centers.map { ($0.x, $0.y) })
        let clusters = ClassroomLayoutGeometry.greedyClusterCount(
            centers: centers.map { ($0.x, $0.y) },
            threshold: 0.18
        )
        // High clusteredness = small pairwise distance relative to count.
        let expectedLoose = min(0.55, 0.12 + 0.06 * Double(max(0, centers.count - 1)))
        let clusteredness = min(1, max(0, 1.0 - pairwise / max(0.08, expectedLoose * 1.4)))
        let faceScale = ClassroomLayoutGeometry.meanFaceScale(input.personRects)
        let pattern = classifyPattern(LayoutClassificationInput(
            peopleN: centers.count,
            hSpread: hSpread,
            vSpread: vSpread,
            pairwise: pairwise,
            clusteredness: clusteredness,
            clusters: clusters,
            board: input.board,
            boardConfidence: input.boardConfidence,
            faceScale: faceScale,
            midBand: CVFeatureFusion.midBandOccupancy(personRects: input.personRects)
        ))

        var values = ClassroomLayoutMetrics.Values()
        values.horizontalSpread = hSpread
        values.verticalSpread = vSpread
        values.clusteredness = clusteredness
        values.estimatedClusterCount = clusters
        values.meanPairwiseDistance = pairwise
        values.pattern = pattern
        values.faceScaleScore = faceScale
        return ClassroomLayoutMetrics(values)
    }

    // MARK: - Internals

    private static func resolvedPersonCount(
        personRects: [ImageNormalizedRect],
        faceCount: Int,
        personCount: Int
    ) -> Int {
        if !personRects.isEmpty { return max(personRects.count, personCount) }
        if faceCount > 0 { return max(faceCount, personCount) }
        return personCount
    }

    private static func countOnlyLayout(peopleN: Int, boardConfidence: Double) -> ClassroomLayoutMetrics {
        guard peopleN > 0 else { return .empty }
        let geometry = countOnlyGeometry(peopleN: peopleN)
        var values = ClassroomLayoutMetrics.Values()
        values.horizontalSpread = geometry.horizontalSpread
        values.verticalSpread = 0.2
        values.clusteredness = geometry.clusteredness
        values.estimatedClusterCount = geometry.clusterCount
        values.meanPairwiseDistance = geometry.pairwiseDistance
        values.pattern = countOnlyPattern(peopleN: peopleN, boardConfidence: boardConfidence)
        values.faceScaleScore = 0.3
        return ClassroomLayoutMetrics(values)
    }

    private static func countOnlyPattern(
        peopleN: Int,
        boardConfidence: Double
    ) -> ClassroomLayoutPattern {
        switch peopleN {
        case 1:
            return countOnlySinglePattern(boardConfidence: boardConfidence)
        case 2:
            return .dyadClose
        case 3...5:
            return countOnlyGroupPattern(boardConfidence: boardConfidence)
        default:
            return countOnlyDensePattern(boardConfidence: boardConfidence)
        }
    }

    private static func countOnlySinglePattern(
        boardConfidence: Double
    ) -> ClassroomLayoutPattern {
        guard boardConfidence >= 0.45 else { return .seatworkScattered }
        return .presentationFocus
    }

    private static func countOnlyGroupPattern(
        boardConfidence: Double
    ) -> ClassroomLayoutPattern {
        guard boardConfidence >= 0.45 else { return .multiCluster }
        return .frontalRows
    }

    private static func countOnlyDensePattern(
        boardConfidence: Double
    ) -> ClassroomLayoutPattern {
        guard boardConfidence >= 0.35 else { return .sparseSpread }
        return .wholeRoomDense
    }

    private static func countOnlyGeometry(
        peopleN: Int
    ) -> (horizontalSpread: Double, clusteredness: Double, clusterCount: Int, pairwiseDistance: Double) {
        guard peopleN > 2 else { return (0.25, 0.7, 1, 0.12) }
        return (peopleN >= 4 ? 0.45 : 0.25, 0.4, max(1, peopleN / 3), 0.28)
    }

    private static func classifyPattern(_ input: LayoutClassificationInput) -> ClassroomLayoutPattern {
        guard input.peopleN > 0 else { return .empty }
        if let smallPattern = classifySmallLayout(input) { return smallPattern }
        if let primaryPattern = classifyGroupPrimary(input) { return primaryPattern }
        if let secondaryPattern = classifyGroupSecondary(input) { return secondaryPattern }
        return classifyFallback(input)
    }

    private static func classifySmallLayout(
        _ input: LayoutClassificationInput
    ) -> ClassroomLayoutPattern? {
        if input.peopleN == 1 { return classifySinglePerson(input) }
        if input.peopleN == 2 { return classifyPair(input) }
        return nil
    }

    private static func classifySinglePerson(
        _ input: LayoutClassificationInput
    ) -> ClassroomLayoutPattern {
        if input.boardStrong { return .presentationFocus }
        return input.faceScale >= 0.45 ? .presentationFocus : .seatworkScattered
    }

    private static func classifyPair(
        _ input: LayoutClassificationInput
    ) -> ClassroomLayoutPattern {
        if input.pairwise <= 0.22 || input.clusteredness >= 0.55 {
            return .dyadClose
        }
        return input.boardOK ? .frontalRows : .seatworkScattered
    }

    private static func classifyGroupPrimary(
        _ input: LayoutClassificationInput
    ) -> ClassroomLayoutPattern? {
        if isPrimaryCircle(input) { return .circleLike }
        if isSecondaryCircle(input) { return .circleLike }
        if isWholeRoomDense(input) { return .wholeRoomDense }
        if isSparseSpread(input) { return .sparseSpread }
        return nil
    }

    private static func classifyGroupSecondary(
        _ input: LayoutClassificationInput
    ) -> ClassroomLayoutPattern? {
        if isMultiCluster(input) { return .multiCluster }
        if input.boardOK && input.midBand >= 0.35 { return .frontalRows }
        if isSeatworkScattered(input) { return .seatworkScattered }
        return nil
    }

    private static func classifyFallback(_ input: LayoutClassificationInput) -> ClassroomLayoutPattern {
        if input.boardConfidence < 0.45 { return .multiCluster }
        if input.boardOK { return .frontalRows }
        return .seatworkScattered
    }

    private static func isPrimaryCircle(_ input: LayoutClassificationInput) -> Bool {
        input.peopleN >= 4
            && input.midBand >= 0.62
            && input.hSpread >= 0.28
            && input.boardConfidence < 0.40
    }

    private static func isSecondaryCircle(_ input: LayoutClassificationInput) -> Bool {
        input.peopleN >= 3
            && input.midBand >= 0.72
            && input.hSpread >= 0.22
            && !input.boardStrong
    }

    private static func isWholeRoomDense(_ input: LayoutClassificationInput) -> Bool {
        if input.peopleN >= 6 { return true }
        return input.peopleN >= 5 && input.hSpread >= 0.35 && input.midBand < 0.72
    }

    private static func isSparseSpread(_ input: LayoutClassificationInput) -> Bool {
        guard input.peopleN >= 3, input.boardConfidence < 0.45 else { return false }
        return input.midBand < 0.38 || input.pairwise >= 0.32
    }

    private static func isMultiCluster(_ input: LayoutClassificationInput) -> Bool {
        guard input.peopleN >= 3, input.boardConfidence < 0.55 else { return false }
        guard input.clusters >= 2 || hasClusterGeometry(input) else { return false }
        return input.clusters >= 2 || input.peopleN >= 4
    }

    private static func hasClusterGeometry(_ input: LayoutClassificationInput) -> Bool {
        input.clusteredness >= 0.35
            && input.clusteredness <= 0.75
            && input.hSpread >= 0.18
    }

    private static func isSeatworkScattered(_ input: LayoutClassificationInput) -> Bool {
        input.peopleN >= 3
            && input.pairwise >= 0.25
            && input.clusters >= max(2, input.peopleN / 2)
            && input.boardConfidence < 0.4
    }

}

private struct LayoutClassificationInput: Sendable {
    let peopleN: Int
    let hSpread: Double
    let vSpread: Double
    let pairwise: Double
    let clusteredness: Double
    let clusters: Int
    let board: ImageNormalizedRect?
    let boardConfidence: Double
    let faceScale: Double
    let midBand: Double

    var boardOK: Bool { boardConfidence >= 0.40 }
    var boardStrong: Bool { boardConfidence >= 0.55 }
}
