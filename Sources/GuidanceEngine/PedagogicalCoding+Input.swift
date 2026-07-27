import Foundation

public struct PedagogicalCodeInput: Sendable {
    public struct Context: Sendable {
        public var cv: CVFeatures
        public var scene: TeachingSceneAssessment
        public init(cv: CVFeatures, scene: TeachingSceneAssessment) { self.cv = cv; self.scene = scene }
    }
    public struct Settings: Sendable {
        public var teachingSituation: TeachingSituationID
        public var frame: FrameMetrics
        public var analysisFocus: CodingAnalysisFocus?
        public init(teachingSituation: TeachingSituationID = .frontalBoardInstruction, frame: FrameMetrics = FrameMetrics(), analysisFocus: CodingAnalysisFocus? = nil) { self.teachingSituation = teachingSituation; self.frame = frame; self.analysisFocus = analysisFocus }
    }
    public struct Values: Sendable {
        public var context: Context
        public var settings: Settings
        public init(context: Context, settings: Settings = .init()) { self.context = context; self.settings = settings }
    }
    public let cv: CVFeatures
    public let scene: TeachingSceneAssessment
    public let teachingSituation: TeachingSituationID
    public let frame: FrameMetrics
    public let analysisFocus: CodingAnalysisFocus?

    public init(cv: CVFeatures, scene: TeachingSceneAssessment, settings: Settings = .init()) {
        self.init(.init(context: .init(cv: cv, scene: scene), settings: settings))
    }

    public init(_ values: Values) { cv = values.context.cv; scene = values.context.scene; teachingSituation = values.settings.teachingSituation; frame = values.settings.frame; analysisFocus = values.settings.analysisFocus }
}

public extension PedagogicalCoder {
    static func code(
        cv: CVFeatures,
        scene: TeachingSceneAssessment,
        teachingSituation: TeachingSituationID
    ) -> PedagogicalCodingResult {
        code(PedagogicalCodeInput(
            cv: cv,
            scene: scene,
            settings: .init(teachingSituation: teachingSituation)
        ))
    }

    static func code(
        cv: CVFeatures,
        scene: TeachingSceneAssessment,
        teachingSituation: TeachingSituationID,
        frame: FrameMetrics
    ) -> PedagogicalCodingResult {
        code(PedagogicalCodeInput(
            cv: cv,
            scene: scene,
            settings: .init(teachingSituation: teachingSituation, frame: frame)
        ))
    }

    static func code(
        cv: CVFeatures,
        scene: TeachingSceneAssessment,
        teachingSituation: TeachingSituationID,
        analysisFocus: CodingAnalysisFocus?
    ) -> PedagogicalCodingResult {
        code(PedagogicalCodeInput(
            cv: cv,
            scene: scene,
            settings: .init(
                teachingSituation: teachingSituation,
                analysisFocus: analysisFocus
            )
        ))
    }
}
