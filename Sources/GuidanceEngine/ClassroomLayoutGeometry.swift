import Foundation

enum ClassroomLayoutGeometry {
    static func spread(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0.0) {
            $0 + ($1 - mean) * ($1 - mean)
        } / Double(values.count)
        return min(1, sqrt(variance) / 0.35)
    }

    static func meanPairwise(_ points: [(Double, Double)]) -> Double {
        guard points.count >= 2 else { return 0 }
        var sum = 0.0
        var count = 0
        for first in 0..<points.count {
            for second in (first + 1)..<points.count {
                let deltaX = points[first].0 - points[second].0
                let deltaY = points[first].1 - points[second].1
                sum += sqrt(deltaX * deltaX + deltaY * deltaY)
                count += 1
            }
        }
        return safeMean(sum: sum, count: count)
    }

    static func greedyClusterCount(
        centers: [(Double, Double)],
        threshold: Double
    ) -> Int {
        guard !centers.isEmpty else { return 0 }
        var assigned = [Bool](repeating: false, count: centers.count)
        var count = 0
        for index in 0..<centers.count {
            if assigned[index] { continue }
            count += 1
            assigned[index] = true
            assignNeighbors(
                of: index,
                centers: centers,
                threshold: threshold,
                assigned: &assigned
            )
        }
        return count
    }

    static func meanFaceScale(_ rects: [ImageNormalizedRect]) -> Double {
        guard !rects.isEmpty else { return 0 }
        let heights = rects.map(\.height)
        let meanHeight = heights.reduce(0, +) / Double(heights.count)
        if meanHeight < 0.03 { return 0.2 }
        if meanHeight <= 0.14 {
            return 0.55 + min(0.4, (meanHeight - 0.03) / 0.11 * 0.4)
        }
        if meanHeight <= 0.35 { return 0.75 }
        return max(0.25, 1 - (meanHeight - 0.35))
    }

    private static func assignNeighbors(
        of index: Int,
        centers: [(Double, Double)],
        threshold: Double,
        assigned: inout [Bool]
    ) {
        for candidate in (index + 1)..<centers.count {
            if assigned[candidate] { continue }
            let deltaX = centers[index].0 - centers[candidate].0
            let deltaY = centers[index].1 - centers[candidate].1
            if sqrt(deltaX * deltaX + deltaY * deltaY) <= threshold {
                assigned[candidate] = true
            }
        }
    }

    private static func safeMean(sum: Double, count: Int) -> Double {
        guard count > 0 else { return 0 }
        return min(1, sum / Double(count))
    }
}
