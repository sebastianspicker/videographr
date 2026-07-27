import Foundation

// MARK: - Coding segment timeline (continuous take research log)

/// One coded segment along a continuous take (Derry continuous recording + script analysis).
public struct CodingSegment: Equatable, Codable, Sendable, Identifiable {
    public struct Values: Sendable {
        public var id = UUID()
        public var startedAt = Date()
        public var endedAt: Date?
        public var durationSeconds = 0.0
        public var sceneType = ""
        public var layoutPattern = ""
        public var primaryTIMSS = ""
        public var primaryGTI = ""
        public var presetMatchScore = 0.0
        public var overallConfidence = 0.0
        public var snapshot: ResearchCodingSnapshot?

        public init() {}
    }

    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var durationSeconds: Double
    public var sceneType: String
    public var layoutPattern: String
    public var primaryTIMSS: String
    public var primaryGTI: String
    public var presetMatchScore: Double
    public var overallConfidence: Double
    public var snapshot: ResearchCodingSnapshot?

    public init(_ values: Values) {
        (id, startedAt, endedAt) = (values.id, values.startedAt, values.endedAt)
        durationSeconds = max(0, values.durationSeconds)
        (sceneType, layoutPattern) = (values.sceneType, values.layoutPattern)
        (primaryTIMSS, primaryGTI) = (values.primaryTIMSS, values.primaryGTI)
        presetMatchScore = min(1, max(0, values.presetMatchScore))
        overallConfidence = min(1, max(0, values.overallConfidence))
        snapshot = values.snapshot
    }
}

/// Builds a segment timeline when scene/TIMSS primary changes during a continuous take.
public struct CodingSegmentTimeline: Equatable, Codable, Sendable {
    /// Bounds long/noisy takes while retaining at least 102 minutes at the one-second minimum.
    public static let maxSegments = 2_048

    public private(set) var segments: [CodingSegment]
    public var minSegmentSeconds: Double

    public init(minSegmentSeconds: Double = 3) {
        self.segments = []
        self.minSegmentSeconds = max(1, minSegmentSeconds)
    }

    private enum CodingKeys: String, CodingKey {
        case segments
        case minSegmentSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSegments = try container.decodeIfPresent([CodingSegment].self, forKey: .segments) ?? []
        segments = Array(decodedSegments.suffix(Self.maxSegments))
        minSegmentSeconds = max(
            1,
            try container.decodeIfPresent(Double.self, forKey: .minSegmentSeconds) ?? 3
        )
    }

    public mutating func reset() {
        segments.removeAll()
    }

    /// Observe a new coding snapshot; opens/closes segments on structural change.
    public mutating func observe(
        snapshot: ResearchCodingSnapshot,
        at date: Date = Date()
    ) {
        let key = "\(snapshot.sceneType)|\(snapshot.primaryTIMSS)|\(snapshot.layoutPattern)"
        if var last = segments.last {
            let lastKey = "\(last.sceneType)|\(last.primaryTIMSS)|\(last.layoutPattern)"
            if lastKey == key {
                last.endedAt = date
                last.durationSeconds = max(0, date.timeIntervalSince(last.startedAt))
                last.presetMatchScore = snapshot.presetMatchScore
                last.overallConfidence = snapshot.overallConfidence
                last.snapshot = snapshot
                segments[segments.count - 1] = last
                return
            }
            // Close previous if long enough; otherwise merge into new segment start.
            last.endedAt = date
            last.durationSeconds = max(0, date.timeIntervalSince(last.startedAt))
            segments[segments.count - 1] = last
            if last.durationSeconds < minSegmentSeconds, segments.count >= 1 {
                // Drop ultra-short flicker segments (Derry anti-flicker).
                segments.removeLast()
            }
        }
        var values = CodingSegment.Values()
        values.startedAt = date
        values.sceneType = snapshot.sceneType
        values.layoutPattern = snapshot.layoutPattern
        values.primaryTIMSS = snapshot.primaryTIMSS
        values.primaryGTI = snapshot.primaryGTI
        values.presetMatchScore = snapshot.presetMatchScore
        values.overallConfidence = snapshot.overallConfidence
        values.snapshot = snapshot
        segments.append(CodingSegment(values))
        if segments.count > Self.maxSegments {
            segments.removeFirst(segments.count - Self.maxSegments)
        }
    }

    public mutating func close(at date: Date = Date()) {
        guard var last = segments.last else { return }
        last.endedAt = date
        last.durationSeconds = max(0, date.timeIntervalSince(last.startedAt))
        segments[segments.count - 1] = last
    }

    /// Dominant TIMSS activity by total duration.
    public var dominantTIMSS: String? {
        var totals: [String: Double] = [:]
        for s in segments {
            totals[s.primaryTIMSS, default: 0] += max(s.durationSeconds, 0.1)
        }
        var dominant: String?
        var longestDuration = -Double.infinity
        for segment in segments.reversed() {
            let duration = totals[segment.primaryTIMSS] ?? 0
            if duration > longestDuration {
                dominant = segment.primaryTIMSS
                longestDuration = duration
            }
        }
        return dominant
    }

    public var totalDurationSeconds: Double {
        segments.map(\.durationSeconds).reduce(0, +)
    }
}
