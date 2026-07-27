// MARK: - Coding completeness and calibration

public struct PedagogicalCodingCompleteness: Equatable, Sendable {
    public var ipnComplete: Bool
    public var gtiComplete: Bool
    public var timssNonEmpty: Bool
    public var hasPrimaryTIMSS: Bool
    public var hasPrimaryGTI: Bool
    public var overallConfidence: Double
    public var honestEmptyPath: Bool
    public var summaryDE: String

    public var isCompleteSoftwareLayer: Bool {
        if honestEmptyPath { return true }
        return ipnComplete && gtiComplete && timssNonEmpty && hasPrimaryTIMSS && hasPrimaryGTI
    }

    public static func evaluate(_ coding: PedagogicalCodingResult, cvSucceeded: Bool) -> PedagogicalCodingCompleteness {
        if !cvSucceeded {
            return PedagogicalCodingCompleteness(
                ipnComplete: coding.ipnDimensions.isEmpty,
                gtiComplete: coding.gtiDimensions.isEmpty,
                timssNonEmpty: true,
                hasPrimaryTIMSS: true,
                hasPrimaryGTI: true,
                overallConfidence: coding.overallConfidence,
                honestEmptyPath: coding.ipnDimensions.isEmpty && coding.gtiDimensions.isEmpty,
                summaryDE: "Ehrlicher Leerpfad bei fehlgeschlagenem CV."
            )
        }
        if coding.sceneType == .emptyOrUnusable {
            return PedagogicalCodingCompleteness(
                ipnComplete: coding.ipnDimensions.isEmpty,
                gtiComplete: coding.gtiDimensions.isEmpty,
                timssNonEmpty: coding.primaryTIMSS == .unclearOrNonInstructional,
                hasPrimaryTIMSS: true,
                hasPrimaryGTI: true,
                overallConfidence: coding.overallConfidence,
                honestEmptyPath: coding.ipnDimensions.isEmpty,
                summaryDE: "Leere Szene - TIMSS unklar, keine IPN/GTI-Dimensionen erfunden."
            )
        }
        let ipnOK = coding.ipnDimensions.count == IPNDimensionCode.allCases.count
        let gtiOK = coding.gtiDimensions.count == GTIQualityCode.allCases.count
        let timssOK = !coding.timssActivities.isEmpty
        return PedagogicalCodingCompleteness(
            ipnComplete: ipnOK,
            gtiComplete: gtiOK,
            timssNonEmpty: timssOK,
            hasPrimaryTIMSS: TIMSSActivityCode(rawValue: coding.primaryTIMSS.rawValue) != nil,
            hasPrimaryGTI: GTIQualityCode(rawValue: coding.primaryGTI.rawValue) != nil,
            overallConfidence: coding.overallConfidence,
            honestEmptyPath: false,
            summaryDE: "IPN \(coding.ipnDimensions.count)/\(IPNDimensionCode.allCases.count), GTI \(coding.gtiDimensions.count)/\(GTIQualityCode.allCases.count), TIMSS n=\(coding.timssActivities.count)."
        )
    }
}

/// Soft calibration priors: which IPN/GTI should elevate under which scene (documentation + tests).
public enum PedagogicalCalibrationTable: Sendable {
    public static func expectedElevatedIPN(for scene: TeachingSceneType) -> [IPNDimensionCode] {
        elevatedIPNByScene[scene] ?? []
    }

    private static let boardInstructionIPN: [IPNDimensionCode] = [
        .goalOrientation, .cognitiveActivation, .classroomOrganization
    ]
    private static let dialogueIPN: [IPNDimensionCode] = [
        .learningSupport, .errorCulture, .socialClimate
    ]
    private static let groupIPN: [IPNDimensionCode] = [
        .socialClimate, .learningSupport, .classroomOrganization
    ]
    private static let experimentIPN: [IPNDimensionCode] = [
        .experimentation, .cognitiveActivation, .learningSupport
    ]
    private static let elevatedIPNByScene: [TeachingSceneType: [IPNDimensionCode]] = [
        .boardCentricFrontal: boardInstructionIPN,
        .teacherDemonstration: boardInstructionIPN,
        .studentAtBoard: [.goalOrientation, .cognitiveActivation],
        .dialoguePair: dialogueIPN,
        .multiPersonGroup: groupIPN,
        .circleDiscussion: groupIPN,
        .experimentSpread: experimentIPN,
        .wholeRoomOverview: [.classroomOrganization, .socialClimate],
        .transitionMoment: [.classroomOrganization, .socialClimate],
        .individualSeatwork: [.cognitiveActivation, .classroomOrganization],
        .actorsWithoutBoard: [.cognitiveActivation, .classroomOrganization],
        .boardOnly: [.goalOrientation]
    ]

    public static func expectedElevatedGTI(for scene: TeachingSceneType) -> [GTIQualityCode] {
        elevatedGTIByScene[scene] ?? [.instructionalQuality]
    }

    private static let elevatedGTIByScene: [TeachingSceneType: [GTIQualityCode]] = [
        .boardCentricFrontal: [.subjectClarity, .instructionalQuality, .cognitiveEngagement],
        .teacherDemonstration: [.subjectClarity, .instructionalQuality, .cognitiveEngagement],
        .studentAtBoard: [.subjectClarity, .instructionalQuality, .cognitiveEngagement],
        .dialoguePair: [.discourseQuality, .assessmentFeedback, .socialEmotionalSupport],
        .multiPersonGroup: [.socialEmotionalSupport, .studentEngagementProxy, .discourseQuality],
        .circleDiscussion: [.socialEmotionalSupport, .studentEngagementProxy, .discourseQuality],
        .experimentSpread: [.cognitiveEngagement, .instructionalQuality, .studentEngagementProxy],
        .wholeRoomOverview: [.classroomManagement, .socialEmotionalSupport],
        .transitionMoment: [.classroomManagement, .socialEmotionalSupport],
        .individualSeatwork: [.cognitiveEngagement, .classroomManagement]
    ]

    /// Returns true if at least one expected elevated dimension is among the top-half levels.
    public static func ipnElevationHolds(coding: PedagogicalCodingResult, scene: TeachingSceneType) -> Bool {
        expectedCodesAreElevated(
            expectedElevatedIPN(for: scene).map(\.rawValue),
            within: coding.ipnDimensions
        )
    }

    public static func gtiElevationHolds(coding: PedagogicalCodingResult, scene: TeachingSceneType) -> Bool {
        expectedCodesAreElevated(
            expectedElevatedGTI(for: scene).map(\.rawValue),
            within: coding.gtiDimensions
        )
    }

    private static func expectedCodesAreElevated(
        _ expected: [String],
        within assignments: [PedagogicalCodeAssignment]
    ) -> Bool {
        guard !expected.isEmpty else { return assignments.isEmpty }
        let sorted = assignments.sorted(by: stableAssignmentOrder)
        let top = Set(sorted.prefix(max(3, sorted.count / 2)).map(\.code))
        return expected.contains { top.contains($0) }
    }

    private static func stableAssignmentOrder(
        _ lhs: PedagogicalCodeAssignment,
        _ rhs: PedagogicalCodeAssignment
    ) -> Bool {
        lhs.level == rhs.level ? lhs.code < rhs.code : lhs.level > rhs.level
    }
}
