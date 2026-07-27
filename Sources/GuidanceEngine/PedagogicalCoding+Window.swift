import Foundation

public struct PedagogicalCodingWindow: Equatable, Sendable {
    public let capacity: Int
    public private(set) var samples: [PedagogicalCodingResult]

    public init(capacity: Int = 8) {
        self.capacity = max(1, capacity)
        samples = []
    }

    public mutating func push(_ result: PedagogicalCodingResult) {
        samples.append(result)
        if samples.count > capacity { samples.removeFirst(samples.count - capacity) }
    }

    public mutating func reset() { samples.removeAll() }

    public func aggregate() -> PedagogicalCodingResult? {
        guard let last = samples.last else { return nil }
        guard samples.count > 1 else { return last }
        let ipn = aggregateAssignments(IPNDimensionCode.allCases.map(\.rawValue), family: .ipnProcessQuality)
        let timss = aggregateAssignments(stableCodes(samples.flatMap(\.timssCodes)), family: .timssActivityScript)
        let gti = aggregateAssignments(GTIQualityCode.allCases.map(\.rawValue), family: .gtiQuality)
        return aggregateResult(ipn: ipn, timss: timss, gti: gti, last: last)
    }

    private func aggregateAssignments(_ codes: [String], family: PedagogicalCodeFamily) -> [PedagogicalCodeAssignment] {
        codes.compactMap { aggregateAssignment(code: $0, family: family) }.sorted { rankedBefore($0, $1, family: family) }
    }

    private func aggregateAssignment(code: String, family: PedagogicalCodeFamily) -> PedagogicalCodeAssignment? {
        let values = assignments(family).filter { $0.code == code }
        guard let recent = values.last else { return nil }
        let level = values.map(\.level).reduce(0, +) / Double(values.count)
        let confidence = values.map(\.confidence).reduce(0, +) / Double(values.count)
        let identity = PedagogicalCodeAssignment.Identity(id: "\(family.rawValue)-\(code)", family: family)
        let descriptor = PedagogicalCodeAssignment.Descriptor(code: code, labelDE: recent.labelDE)
        let measurement = PedagogicalCodeAssignment.Measurement(level: level, confidence: confidence)
        let assignmentValues = PedagogicalCodeAssignment.Values(identity: identity, descriptor: descriptor, measurement: measurement, rationaleDE: "Fenster-Aggregation (\(samples.count) Beobachtungen). \(recent.rationaleDE)")
        return PedagogicalCodeAssignment(assignmentValues)
    }

    private func aggregateResult(ipn: [PedagogicalCodeAssignment], timss: [PedagogicalCodeAssignment], gti: [PedagogicalCodeAssignment], last: PedagogicalCodingResult) -> PedagogicalCodingResult {
        let primary = timss.first.flatMap { TIMSSActivityCode(rawValue: $0.code) } ?? last.primaryTIMSS
        let primaryGTI = gti.first.flatMap { GTIQualityCode(rawValue: $0.code) } ?? last.primaryGTI
        let confidence = samples.map(\.overallConfidence).reduce(0, +) / Double(samples.count)
        let scene = mostRecentMode(samples.map(\.sceneType)) ?? last.sceneType
        let layout = mostRecentMode(samples.map(\.layoutPattern)) ?? last.layoutPattern
        let assignments = PedagogicalCodingResult.Assignments(ipnDimensions: ipn, timssActivities: timss, gtiDimensions: gti)
        let primaryCodes = PedagogicalCodingResult.PrimaryCodes(timss: primary, gti: primaryGTI)
        let content = PedagogicalCodingResult.Content(assignments: assignments, primaryCodes: primaryCodes, overallConfidence: confidence, summaryDE: "Zeitfenster (\(samples.count)): TIMSS \(primary.titleDE); GTI \(primaryGTI.titleDE); Szene \(scene.titleDE); Layout \(layout.titleDE).")
        let context = PedagogicalCodingResult.Context(sceneType: scene, teachingSituation: last.teachingSituation, layoutPattern: layout, analysisFocus: last.analysisFocus)
        return PedagogicalCodingResult(.init(content: content, context: context))
    }

    private func assignments(_ family: PedagogicalCodeFamily) -> [PedagogicalCodeAssignment] {
        samples.flatMap { sample in
            switch family {
            case .ipnProcessQuality: return sample.ipnDimensions
            case .timssActivityScript: return sample.timssActivities
            case .gtiQuality: return sample.gtiDimensions
            }
        }
    }

    private func stableCodes(_ codes: [String]) -> [String] {
        var seen = Set<String>()
        return codes.filter { seen.insert($0).inserted }
    }

    private func rankedBefore(_ lhs: PedagogicalCodeAssignment, _ rhs: PedagogicalCodeAssignment, family: PedagogicalCodeFamily) -> Bool {
        if lhs.level != rhs.level { return lhs.level > rhs.level }
        let left = lastIndex(lhs.code, family: family)
        let right = lastIndex(rhs.code, family: family)
        return left == right ? lhs.code < rhs.code : left > right
    }

    private func lastIndex(_ code: String, family: PedagogicalCodeFamily) -> Int {
        samples.lastIndex { assignments($0, family: family).contains { $0.code == code } } ?? -1
    }

    private func assignments(_ sample: PedagogicalCodingResult, family: PedagogicalCodeFamily) -> [PedagogicalCodeAssignment] {
        switch family {
        case .ipnProcessQuality: return sample.ipnDimensions
        case .timssActivityScript: return sample.timssActivities
        case .gtiQuality: return sample.gtiDimensions
        }
    }

    private func mostRecentMode<Value: Hashable>(_ values: [Value]) -> Value? {
        let counts = values.reduce(into: [Value: Int]()) { $0[$1, default: 0] += 1 }
        return values.reversed().max { (counts[$0] ?? 0) < (counts[$1] ?? 0) }
    }
}
