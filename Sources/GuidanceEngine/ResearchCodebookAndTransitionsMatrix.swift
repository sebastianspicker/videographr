// MARK: - Structure matrix compact export (L8)

public struct ResearchStructureMatrixCellValues: Sendable {
    public var preset = ""
    public var fixture = ""
    public var sufficient = false
    public var score = 0.0
    public var scene = ""
    public var matchesPreset = false

    public init() {}
}

public enum ResearchStructureMatrixExport: Sendable {
    public struct Cell: Equatable, Sendable {
        public var preset: String
        public var fixture: String
        public var sufficient: Bool
        public var score: Double
        public var scene: String
        public var matchesPreset: Bool

        public init(_ values: ResearchStructureMatrixCellValues) {
            preset = values.preset
            fixture = values.fixture
            sufficient = values.sufficient
            score = values.score
            scene = values.scene
            matchesPreset = values.matchesPreset
        }
    }

    public static var defaultFixtures: [(name: String, cv: CVFeatures)] {
        [
            ("classroom", .fixtureClassroomPresent()),
            ("group", .fixtureGroupWork()),
            ("dialogue", .fixtureDialoguePair()),
            ("partner", .fixturePartnerWork()),
            ("studentBoard", .fixtureStudentAtBoard()),
            ("experiment", .fixtureExperimentSpread()),
            ("circle", .fixtureCircleDiscussion()),
            ("management", .fixtureManagementOverview()),
            ("seatwork", .fixtureSeatworkScattered()),
            ("demo", .fixtureTeacherDemonstration()),
            ("transition", .fixtureTransitionOrganization()),
            ("formative", .fixtureFormativeAssessment()),
            ("empty", .fixtureEmptyRoom()),
            ("failed", .fixtureAnalysisFailed())
        ]
    }

    public static func build(
        fixtures: [(name: String, cv: CVFeatures)] = defaultFixtures
    ) -> [Cell] {
        var cells: [Cell] = []
        for id in TeachingSituationID.allCases {
            for fixture in fixtures {
                let scene = TeachingSceneAssessor.assess(cv: fixture.cv, preset: id)
                let structure = ResearchStructureAssessor.assess(
                    cv: fixture.cv,
                    scene: scene,
                    teachingSituation: id
                )
                var values = ResearchStructureMatrixCellValues()
                values.preset = id.rawValue
                values.fixture = fixture.name
                values.sufficient = structure.sufficient
                values.score = structure.score
                values.scene = scene.sceneType.rawValue
                values.matchesPreset = scene.matchesPreset
                cells.append(Cell(values))
            }
        }
        return cells
    }

    public static var intendedPairs: [(fixture: String, preset: TeachingSituationID)] {
        [
            ("classroom", .frontalBoardInstruction),
            ("group", .collaborativeGroupWork),
            ("dialogue", .teacherLedDialogue),
            ("partner", .partnerWork),
            ("studentBoard", .studentBoardPresentation),
            ("experiment", .handsOnExperiment),
            ("circle", .circleOrPlenumDiscussion),
            ("management", .classroomManagementOverview),
            ("seatwork", .individualSeatwork),
            ("demo", .teacherDemonstration),
            ("transition", .transitionOrganization),
            ("formative", .formativeAssessmentDialogue)
        ]
    }
}
