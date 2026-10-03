import Foundation

public extension CVFeatureFusion {
    /// Writing-surface text corroboration: fraction of text mass overlapping board (or upper writing band).
    /// Used by production Vision adapter (OCR) and pure tests - not pedagogical content coding.
    static func boardTextSupport(
        board: ImageNormalizedRect?,
        textRects: [ImageNormalizedRect]
    ) -> Double {
        guard !textRects.isEmpty else { return 0 }
        let totalArea = textRects.reduce(0.0) { $0 + max(1e-9, $1.area) }
        guard totalArea > 0 else { return 0 }

        if let board {
            return boardTextSupport(on: board, textRects: textRects, totalArea: totalArea)
        }
        return upperBandTextSupport(textRects, totalArea: totalArea)
    }

    private static func boardTextSupport(
        on board: ImageNormalizedRect,
        textRects: [ImageNormalizedRect],
        totalArea: Double
    ) -> Double {
        let overlap = textRects.reduce(0.0) { $0 + max(1e-9, $1.area) * board.iou(with: $1) }
        let inside = textRects
            .filter { boardContains($0.centerX, $0.centerY, in: board) }
            .reduce(0.0) { $0 + max(1e-9, $1.area) }
        let fraction = max(overlap, inside) / totalArea
        let densityBoost = min(0.25, Double(textRects.count) * 0.04)
        return min(1, max(0, 0.55 * fraction + 0.25 * min(1, totalArea * 8) + densityBoost))
    }

    private static func boardContains(_ x: Double, _ y: Double, in board: ImageNormalizedRect) -> Bool {
        x >= board.x && x <= board.x + board.width && y >= board.y && y <= board.y + board.height
    }

    private static func upperBandTextSupport(_ textRects: [ImageNormalizedRect], totalArea: Double) -> Double {
        let inBand = textRects
            .filter { $0.centerY >= 0.08 && $0.centerY <= 0.55 }
            .reduce(0.0) { $0 + max(1e-9, $1.area) }
        let fraction = inBand / totalArea
        let countScore = min(1, Double(textRects.count) / 6.0)
        return min(1, max(0, 0.45 * fraction + 0.35 * countScore + 0.2 * min(1, totalArea * 6)))
    }

    /// Fuse document/saliency/text edge cues into a single boardEdgeSupport score 0...1.
    static func fuseBoardEdgeSupport(
        documentOverlap: Double = 0,
        saliencyOverlap: Double = 0,
        textSupport: Double = 0,
        geometryFallback: Double = 0
    ) -> Double {
        let doc = min(1, max(0, documentOverlap))
        let sal = min(1, max(0, saliencyOverlap))
        let text = min(1, max(0, textSupport))
        let geom = min(1, max(0, geometryFallback))
        let raw = 0.34 * doc + 0.22 * sal + 0.34 * text + 0.10 * geom
        // If only geometry is available, keep a weak but non-zero support.
        if doc <= 0 && sal <= 0 && text <= 0 {
            return min(1, max(0, geom))
        }
        return min(1, max(0, raw))
    }

    /// Mid-band occupancy from joint points (e.g. body-pose necks/roots) in top-left normalized coords.
    static func midBandOccupancy(jointPoints: [(x: Double, y: Double)], midY0: Double = 0.25, midY1: Double = 0.78) -> Double {
        guard !jointPoints.isEmpty else { return 0 }
        let inBand = jointPoints.filter { $0.y >= midY0 && $0.y <= midY1 }.count
        return Double(inBand) / Double(jointPoints.count)
    }

    /// Centroid of joint points (equal weight).
    static func peopleCentroid(jointPoints: [(x: Double, y: Double)]) -> (x: Double, y: Double)? {
        guard !jointPoints.isEmpty else { return nil }
        let sx = jointPoints.reduce(0.0) { $0 + $1.x }
        let sy = jointPoints.reduce(0.0) { $0 + $1.y }
        let n = Double(jointPoints.count)
        return (sx / n, sy / n)
    }

    /// Scale variance of person rects (area or height); high = mixed distances / group depth.
    static func actorScaleVariance(personRects: [ImageNormalizedRect]) -> Double {
        guard personRects.count >= 2 else { return 0 }
        let heights = personRects.map(\.height)
        let mean = heights.reduce(0, +) / Double(heights.count)
        guard mean > 1e-6 else { return 0 }
        let variance = heights.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(heights.count)
        // Map stddev/mean into 0...1 (cv of 0.5 → ~1)
        return min(1, sqrt(variance) / mean / 0.5)
    }
}
