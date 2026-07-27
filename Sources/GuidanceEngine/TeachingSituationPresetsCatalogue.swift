public enum TeachingSituationCatalogue {
    public static let all: [TeachingSituationPreset] = [
        TeachingSituationPreset.make { values in
            values.id = .frontalBoardInstruction
            values.titleDE = "Frontaler Tafelunterricht"
            values.summaryDE = "Weiter Analyseausschnitt: Schreibfläche, Lehrperson und vordere SuS-Reihen gemeinsam im Bild."
            values.expectedScenes = [.boardCentricFrontal]
            values.acceptableScenes = [.studentAtBoard, .dialoguePair]
            values.requiresBoard = true
            values.minPeople = 1
            values.prefersMultiPerson = false
            values.boardEmphasis = 0.9
            values.peopleEmphasis = 0.65
            values.coPresenceEmphasis = 0.85
            values.ipnEmphasis = ["goalOrientation", "classroomOrganization", "cognitiveActivation", "errorCulture"]
            values.expectedTIMSSActivities = ["wholeClassInstruction", "publicBoardWork"]
            values.gtiEmphasis = ["classroomManagement", "instructionalQuality", "subjectClarity", "cognitiveEngagement"]
            values.preferredLayouts = [.frontalRows, .presentationFocus]
            values.mismatchHintDE = "Für Tafelunterricht Schreibfläche und Akteure gemeinsam frontal-seitlich erfassen - nicht nur leere Wand oder reine Gruppenarbeit."
            values.captureGuidanceDE = "Seitlich-frontal aufstellen: Tafel vollständig, Lehrperson und vordere Reihen im Interaktionsband; Stativ brusthoch, Horizont gerade."
            values.researchAnchorDE = "IPN-Videostudie / Seidel: Lehr-Lern-Rahmen mit sichtbarer Ziel- und Organisationsstruktur."
        },
        TeachingSituationPreset.make { values in
            values.id = .teacherLedDialogue
            values.titleDE = "Lehrperson–SuS-Dialog"
            values.summaryDE = "Dialog / IRE-Muster: wenige Akteure lesbar, Interaktionszone zentriert; Tafel als optionaler Kontext."
            values.expectedScenes = [.dialoguePair, .boardCentricFrontal]
            values.acceptableScenes = [.actorsWithoutBoard]
            values.requiresBoard = false
            values.minPeople = 2
            values.prefersMultiPerson = false
            values.boardEmphasis = 0.45
            values.peopleEmphasis = 0.9
            values.coPresenceEmphasis = 0.55
            values.ipnEmphasis = ["learningSupport", "goalOrientation", "socialClimate"]
            values.expectedTIMSSActivities = ["wholeClassInstruction", "recitationDialogue"]
            values.gtiEmphasis = ["discourseQuality", "socialEmotionalSupport", "assessmentFeedback", "instructionalQuality"]
            values.preferredLayouts = [.dyadClose, .frontalRows]
            values.mismatchHintDE = "Dialog braucht mindestens zwei lesbare Akteure in der Bildmitte - nicht leeren Raum oder nur Tafel."
            values.captureGuidanceDE = "Näher heran: Gesichter der Dialogpartner lesbar, leichte Tafel im Hintergrund ok; wenig Decke, engerer Ausschnitt."
            values.researchAnchorDE = "IRE/Dialogmuster (TIMSS recitation; IPN Lernunterstützung) - Interaktion, nicht nur Tafelwand."
        },
        TeachingSituationPreset.make { values in
            values.id = .collaborativeGroupWork
            values.titleDE = "Gruppenarbeit"
            values.summaryDE = "Mehrpersonen-Cluster in der Interaktionszone; Schreibfläche sekundär. Kooperation und Unterstützung bleiben als menschlich zu interpretierende Vorgänge sichtbar."
            values.expectedScenes = [.multiPersonGroup]
            values.acceptableScenes = [.experimentSpread, .circleDiscussion]
            values.requiresBoard = false
            values.minPeople = 3
            values.prefersMultiPerson = true
            values.boardEmphasis = 0.25
            values.peopleEmphasis = 0.95
            values.coPresenceEmphasis = 0.35
            values.ipnEmphasis = ["learningSupport", "socialClimate", "classroomOrganization"]
            values.expectedTIMSSActivities = ["groupWork", "seatworkCollaborative"]
            values.gtiEmphasis = ["socialEmotionalSupport", "studentEngagementProxy", "discourseQuality"]
            values.preferredLayouts = [.multiCluster, .sparseSpread]
            values.mismatchHintDE = "Gruppenarbeit erfordert mehrere Personen im Bild - frontal-Tafel-only oder leerer Raum passen nicht."
            values.captureGuidanceDE = "Gruppe(n) im Mittelband halten; Tafel darf am Rand sein. Mehrere Köpfe/Oberkörper sichtbar, nicht nur eine Person."
            values.researchAnchorDE = "TIMSS group work / seatwork collaborative; IPN Sozialklima und Lernunterstützung."
        },
        TeachingSituationPreset.make { values in
            values.id = .partnerWork
            values.titleDE = "Partnerarbeit"
            values.summaryDE = "Zwei Akteure in enger Interaktion (Tisch/Paar); Tafel optional im Hintergrund."
            values.expectedScenes = [.dialoguePair]
            values.acceptableScenes = [.multiPersonGroup, .actorsWithoutBoard]
            values.requiresBoard = false
            values.minPeople = 2
            values.prefersMultiPerson = false
            values.boardEmphasis = 0.2
            values.peopleEmphasis = 0.92
            values.coPresenceEmphasis = 0.3
            values.ipnEmphasis = ["learningSupport", "socialClimate"]
            values.expectedTIMSSActivities = ["partnerWork", "seatworkCollaborative"]
            values.gtiEmphasis = ["discourseQuality", "assessmentFeedback", "studentEngagementProxy"]
            values.preferredLayouts = [.dyadClose]
            values.mismatchHintDE = "Partnerarbeit: zwei SuS/Akteure in der Mitte halten - nicht nur Tafel oder Raumübersicht ohne Paar."
            values.captureGuidanceDE = "Paar am Tisch zentrieren; beide Akteure gleichgewichtig; Tafel optional im Hintergrund."
            values.researchAnchorDE = "TIMSS partner work - dyadische Interaktion als Skriptsegment."
        },
        TeachingSituationPreset.make { values in
            values.id = .studentBoardPresentation
            values.titleDE = "SuS-Präsentation an der Tafel"
            values.summaryDE = "Präsentierende Person an der Schreibfläche; Tafelqualität und Nähe Person–Tafel zentral."
            values.expectedScenes = [.studentAtBoard]
            values.acceptableScenes = [.boardCentricFrontal]
            values.requiresBoard = true
            values.minPeople = 1
            values.prefersMultiPerson = false
            values.boardEmphasis = 0.95
            values.peopleEmphasis = 0.75
            values.coPresenceEmphasis = 0.95
            values.ipnEmphasis = ["goalOrientation", "cognitiveActivation", "classroomOrganization"]
            values.expectedTIMSSActivities = ["publicBoardWork", "studentPresentation"]
            values.gtiEmphasis = ["subjectClarity", "cognitiveEngagement", "instructionalQuality", "studentEngagementProxy"]
            values.preferredLayouts = [.presentationFocus, .frontalRows]
            values.mismatchHintDE = "Präsentation: Person und Tafel müssen gemeinsam sichtbar sein (hohe Co-Präsenz)."
            values.captureGuidanceDE = "Schreibfläche dominant, Präsentierende:r darunter/davor; hohe Co-Präsenz Person–Tafel; Gesichter und Tafelinhalt lesbar."
            values.researchAnchorDE = "TIMSS public board work / student presentation; IPN Zielorientierung und kognitive Aktivierung."
        },
        TeachingSituationPreset.make { values in
            values.id = .handsOnExperiment
            values.titleDE = "Experiment / Praktikum"
            values.summaryDE = "Verteilte Akteure und Handlungsraum; Tafel sekundär. Typisch für IPN-Experimentierphasen und Hands-on."
            values.expectedScenes = [.experimentSpread, .multiPersonGroup]
            values.acceptableScenes = [.actorsWithoutBoard, .wholeRoomOverview]
            values.requiresBoard = false
            values.minPeople = 2
            values.prefersMultiPerson = true
            values.boardEmphasis = 0.2
            values.peopleEmphasis = 0.9
            values.coPresenceEmphasis = 0.25
            values.ipnEmphasis = ["experimentation", "cognitiveActivation", "learningSupport", "classroomOrganization"]
            values.expectedTIMSSActivities = ["experimentLab", "groupWork"]
            values.gtiEmphasis = ["cognitiveEngagement", "instructionalQuality", "studentEngagementProxy", "classroomManagement"]
            values.preferredLayouts = [.sparseSpread, .multiCluster]
            values.mismatchHintDE = "Experiment: verteilte Akteure im Handlungsraum zeigen - nicht nur leere Tafelwand."
            values.captureGuidanceDE = "Weiterer Ausschnitt auf Handlungsraum/Material; mehrere Akteure verteilt ok; Tafel sekundär."
            values.researchAnchorDE = "IPN-Experimentierphasen; TIMSS experiment/lab activity script."
        },
        TeachingSituationPreset.make { values in
            values.id = .classroomManagementOverview
            values.titleDE = "Klassenführung / Übersicht"
            values.summaryDE = "Weiter Ausschnitt zur Beobachtung von Organisations- und Managementereignissen (whole-room)."
            values.expectedScenes = [.wholeRoomOverview, .multiPersonGroup]
            values.acceptableScenes = [.experimentSpread, .circleDiscussion]
            values.requiresBoard = false
            values.minPeople = 3
            values.prefersMultiPerson = true
            values.boardEmphasis = 0.35
            values.peopleEmphasis = 0.95
            values.coPresenceEmphasis = 0.4
            values.ipnEmphasis = ["classroomOrganization", "socialClimate"]
            values.expectedTIMSSActivities = ["transitionOrganization", "wholeClassInstruction"]
            values.gtiEmphasis = ["classroomManagement", "socialEmotionalSupport", "studentEngagementProxy"]
            values.preferredLayouts = [.wholeRoomDense, .multiCluster]
            values.mismatchHintDE = "Klassenführung: möglichst viele SuS im Überblick - ein enger Tafel-Close-up zeigt die Gruppe nicht."
            values.captureGuidanceDE = "Hoher Standpunkt oder weiter Winkel: möglichst viele SuS und Raumstruktur; Managementereignisse sichtbar."
            values.researchAnchorDE = "Klassenführung / whole-room monitoring (TIMSS transition/organization; IPN Organisation)."
        },
        TeachingSituationPreset.make { values in
            values.id = .circleOrPlenumDiscussion
            values.titleDE = "Kreisgespräch / Plenum"
            values.summaryDE = "Sitzkreis oder offenes Plenum; Personen im Mittelband, Tafel oft dezentral."
            values.expectedScenes = [.circleDiscussion, .multiPersonGroup]
            values.acceptableScenes = [.dialoguePair, .wholeRoomOverview]
            values.requiresBoard = false
            values.minPeople = 3
            values.prefersMultiPerson = true
            values.boardEmphasis = 0.15
            values.peopleEmphasis = 0.95
            values.coPresenceEmphasis = 0.2
            values.ipnEmphasis = ["socialClimate", "learningSupport", "goalOrientation"]
            values.expectedTIMSSActivities = ["discussionPlenum", "wholeClassInstruction"]
            values.gtiEmphasis = ["discourseQuality", "socialEmotionalSupport", "studentEngagementProxy"]
            values.preferredLayouts = [.circleLike, .multiCluster]
            values.mismatchHintDE = "Kreis/Plenum braucht mehrere Personen in der Interaktionszone - reine Tafelansicht reicht nicht."
            values.captureGuidanceDE = "Kreis oder Plenum im Mittelband: mehrere Personen, Tafel oft dezentral; offene Sitzordnung erfassen."
            values.researchAnchorDE = "TIMSS discussion/plenum; IPN Sozialklima und partizipative Interaktion."
        },
        TeachingSituationPreset.make { values in
            values.id = .individualSeatwork
            values.titleDE = "Individuelle Stillarbeit"
            values.summaryDE = "Verstreute Einzelarbeit: mehrere Akteure ohne enge Cluster; Tafel sekundär. TIMSS seatwork individual."
            values.expectedScenes = [.individualSeatwork, .actorsWithoutBoard]
            values.acceptableScenes = [.multiPersonGroup, .wholeRoomOverview]
            values.requiresBoard = false
            values.minPeople = 2
            values.prefersMultiPerson = true
            values.boardEmphasis = 0.15
            values.peopleEmphasis = 0.85
            values.coPresenceEmphasis = 0.15
            values.ipnEmphasis = ["classroomOrganization", "cognitiveActivation", "learningSupport"]
            values.expectedTIMSSActivities = ["seatworkIndividual"]
            values.gtiEmphasis = ["cognitiveEngagement", "classroomManagement", "instructionalQuality"]
            values.preferredLayouts = [.seatworkScattered, .sparseSpread]
            values.mismatchHintDE = "Stillarbeit: verstreute Einzelakteure zeigen - nicht nur Tafel-Close-up oder enges Dialogpaar."
            values.captureGuidanceDE = "Weiterer Ausschnitt: mehrere Einzelarbeitsplätze sichtbar; Tafel optional am Rand."
            values.researchAnchorDE = "TIMSS seatwork individual; IPN Organisation und kognitive Aktivierung in Arbeitsphasen."
        },
        TeachingSituationPreset.make { values in
            values.id = .teacherDemonstration
            values.titleDE = "Lehrperson-Demonstration"
            values.summaryDE = "Modellieren an der Tafel/Material: Lehrperson dominant an Schreibfläche; hohe Co-Präsenz und Text/Tafelqualität."
            values.expectedScenes = [.teacherDemonstration, .studentAtBoard, .boardCentricFrontal]
            values.acceptableScenes = [.boardOnly]
            values.requiresBoard = true
            values.minPeople = 1
            values.prefersMultiPerson = false
            values.boardEmphasis = 0.95
            values.peopleEmphasis = 0.7
            values.coPresenceEmphasis = 0.9
            values.ipnEmphasis = ["goalOrientation", "cognitiveActivation", "classroomOrganization"]
            values.expectedTIMSSActivities = ["publicBoardWork", "wholeClassInstruction"]
            values.gtiEmphasis = ["subjectClarity", "instructionalQuality", "cognitiveEngagement", "classroomManagement"]
            values.preferredLayouts = [.presentationFocus, .frontalRows]
            values.mismatchHintDE = "Demonstration: Lehrperson und Schreibfläche gemeinsam - nicht leere Gruppe ohne Tafel."
            values.captureGuidanceDE = "Tafel dominant, Lehrperson davor/darunter; Tafelinhalt lesbar (Text/Struktur); vordere Reihen optional."
            values.researchAnchorDE = "TIMSS public board work / whole-class modeling; IPN Zielklarheit und kognitive Aktivierung."
        },
        TeachingSituationPreset.make { values in
            values.id = .transitionOrganization
            values.titleDE = "Übergang / Organisation"
            values.summaryDE = "Übergangs- und Organisationsphasen: Raumübersicht, viele Akteure, Managementereignisse (TIMSS transition)."
            values.expectedScenes = [.transitionMoment, .wholeRoomOverview]
            values.acceptableScenes = [.multiPersonGroup, .experimentSpread]
            values.requiresBoard = false
            values.minPeople = 3
            values.prefersMultiPerson = true
            values.boardEmphasis = 0.25
            values.peopleEmphasis = 0.9
            values.coPresenceEmphasis = 0.3
            values.ipnEmphasis = ["classroomOrganization", "socialClimate"]
            values.expectedTIMSSActivities = ["transitionOrganization"]
            values.gtiEmphasis = ["classroomManagement", "socialEmotionalSupport"]
            values.preferredLayouts = [.wholeRoomDense, .sparseSpread]
            values.mismatchHintDE = "Übergänge brauchen Raumübersicht mit mehreren Akteuren - ein enger Tafelausschnitt zeigt den Übergangsraum nicht."
            values.captureGuidanceDE = "Weiter Winkel / höherer Standpunkt: Bewegung und Organisationsgeschehen im ganzen Raum."
            values.researchAnchorDE = "TIMSS transition/organization; IPN Klassenführung in Übergangsphasen."
        },
        TeachingSituationPreset.make { values in
            values.id = .formativeAssessmentDialogue
            values.titleDE = "Formatives Feedback / Diagnose"
            values.summaryDE = "Diagnose- und Feedback-Dialog: 2–3 lesbare Akteure, moderate Tafel; IPN Lernunterstützung und Fehlerkultur-Proxy."
            values.expectedScenes = [.dialoguePair, .boardCentricFrontal]
            values.acceptableScenes = [.studentAtBoard, .actorsWithoutBoard]
            values.requiresBoard = false
            values.minPeople = 2
            values.prefersMultiPerson = false
            values.boardEmphasis = 0.4
            values.peopleEmphasis = 0.95
            values.coPresenceEmphasis = 0.5
            values.ipnEmphasis = ["learningSupport", "errorCulture", "goalOrientation", "cognitiveActivation"]
            values.expectedTIMSSActivities = ["recitationDialogue", "wholeClassInstruction"]
            values.gtiEmphasis = ["assessmentFeedback", "discourseQuality", "socialEmotionalSupport", "subjectClarity"]
            values.preferredLayouts = [.dyadClose, .frontalRows]
            values.mismatchHintDE = "Feedback-Dialog: Gesichter und Interaktion zentrieren - nicht leere Raumübersicht."
            values.captureGuidanceDE = "Nah genug für lesbare Gesichter; Dialogpartner zentriert; Tafel als optionaler Kontext."
            values.researchAnchorDE = "IPN Lernunterstützung und Fehlerkultur (Proxy); TIMSS recitation/dialogue for formative exchange."
        }
    ]

    public static var count: Int { all.count }

    public static func preset(for id: TeachingSituationID) -> TeachingSituationPreset {
        all.first { $0.id == id } ?? all[0]
    }

    public static func preset(forRawValue raw: String) -> TeachingSituationPreset? {
        guard let id = TeachingSituationID(rawValue: raw) else { return nil }
        return preset(for: id)
    }

    /// Minimum rich catalogue size (acceptance bar).
    public static let richMinimumCount = 12
}
