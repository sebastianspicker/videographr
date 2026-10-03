import Foundation
import GuidanceEngine
import SessionCore

extension PedagogicalCoder {
    static func codeTIMSS(
        input: PedagogicalCodingInput,
        preset: TeachingSituationPreset,
        confidence: Double
    ) -> [PedagogicalCodeAssignment] {
        var levels = Dictionary(uniqueKeysWithValues: TIMSSActivityCode.allCases.map { ($0, 0.05) })
        applyTIMSSScene(&levels, input: input, preset: preset)
        applyTIMSSLayout(&levels, input: input, preset: preset)
        applyTIMSSSignals(&levels, input: input)
        applyTIMSSPreset(&levels, preset: preset)
        return TIMSSActivityCode.allCases.compactMap { code in
            let level = levels[code] ?? 0.05
            guard level >= 0.12 || code == .unclearOrNonInstructional || preset.expectedTIMSSActivities.contains(code.rawValue) else { return nil }
            return timssAssignment(code: code, level: level, input: input, preset: preset, confidence: confidence)
        }.sorted(by: stablePedagogicalAssignmentOrder)
    }
}

private func applyTIMSSScene(
    _ levels: inout [TIMSSActivityCode: Double],
    input: PedagogicalCodingInput,
    preset: TeachingSituationPreset
) {
    for (code, level) in timssBaseLevels(scene: input.scene, board: input.board, peopleN: input.peopleN, preset: preset) {
        levels[code] = level
    }
}

private func timssBaseLevels(
    scene: TeachingSceneType,
    board: Double,
    peopleN: Int,
    preset: TeachingSituationPreset
) -> [TIMSSActivityCode: Double] {
    let fixed: [TeachingSceneType: [TIMSSActivityCode: Double]] = [
        .emptyOrUnusable: [.unclearOrNonInstructional: 0.9],
        .boardOnly: [.publicBoardWork: 0.55, .wholeClassInstruction: 0.35, .unclearOrNonInstructional: 0.4, .seatworkIndividual: 0.2],
        .boardCentricFrontal: [.wholeClassInstruction: min(1, 0.75 + 0.15 * board), .publicBoardWork: min(1, 0.55 + 0.35 * board), .recitationDialogue: 0.35, .studentPresentation: 0.2],
        .studentAtBoard: [.studentPresentation: 0.85, .publicBoardWork: 0.75, .wholeClassInstruction: 0.5, .recitationDialogue: 0.3],
        .multiPersonGroup: [.groupWork: 0.85, .seatworkCollaborative: 0.6, .discussionPlenum: 0.32, .partnerWork: 0.2],
        .experimentSpread: [.experimentLab: 0.88, .groupWork: 0.55, .seatworkCollaborative: 0.38, .transitionOrganization: 0.25],
        .wholeRoomOverview: [.transitionOrganization: 0.65, .wholeClassInstruction: 0.52, .groupWork: 0.38, .discussionPlenum: 0.28],
        .circleDiscussion: [.discussionPlenum: 0.88, .wholeClassInstruction: 0.48, .recitationDialogue: 0.42, .groupWork: 0.3],
        .individualSeatwork: [.seatworkIndividual: 0.88, .seatworkCollaborative: 0.28, .groupWork: 0.2, .transitionOrganization: 0.18],
        .teacherDemonstration: [.publicBoardWork: min(1, 0.78 + 0.15 * board), .wholeClassInstruction: 0.72, .studentPresentation: 0.25, .recitationDialogue: 0.3],
        .transitionMoment: [.transitionOrganization: 0.88, .wholeClassInstruction: 0.35, .groupWork: 0.3, .unclearOrNonInstructional: 0.22]
    ]
    return specialTIMSSLevels(scene: scene, peopleN: peopleN, preset: preset) ?? fixed[scene] ?? [:]
}

private func specialTIMSSLevels(scene: TeachingSceneType, peopleN: Int, preset: TeachingSituationPreset) -> [TIMSSActivityCode: Double]? {
    if scene == .dialoguePair { return dialogueLevels(preset) }
    if scene == .actorsWithoutBoard { return actorLevels(peopleN) }
    return nil
}
private func dialogueLevels(_ preset: TeachingSituationPreset) -> [TIMSSActivityCode: Double] { preset.id == .partnerWork ? [.partnerWork: 0.85, .seatworkCollaborative: 0.55, .recitationDialogue: 0.4] : [.recitationDialogue: 0.82, .partnerWork: 0.42, .wholeClassInstruction: 0.4] }
private func actorLevels(_ peopleN: Int) -> [TIMSSActivityCode: Double] { [.seatworkIndividual: peopleN <= 1 ? 0.65 : 0.35, .partnerWork: peopleN == 2 ? 0.7 : 0.25, .groupWork: peopleN >= 3 ? 0.55 : 0.2, .recitationDialogue: 0.35, .seatworkCollaborative: peopleN >= 2 ? 0.4 : 0.15] }

private func applyTIMSSLayout(
    _ levels: inout [TIMSSActivityCode: Double],
    input: PedagogicalCodingInput,
    preset: TeachingSituationPreset
) {
    let targets: [ClassroomLayoutPattern: (TIMSSActivityCode, Double)] = [
        .multiCluster: (.groupWork, 0.1), .circleLike: (.discussionPlenum, 0.1),
        .sparseSpread: (.experimentLab, 0.1), .seatworkScattered: (.seatworkIndividual, 0.12),
        .presentationFocus: (.publicBoardWork, 0.08), .wholeRoomDense: (.transitionOrganization, 0.08)
    ]
    if input.layout == .dyadClose {
        raise(&levels, preset.id == .partnerWork ? .partnerWork : .recitationDialogue, by: 0.08)
    } else if let target = targets[input.layout] {
        raise(&levels, target.0, by: target.1)
    }
}

private func applyTIMSSSignals(_ levels: inout [TIMSSActivityCode: Double], input: PedagogicalCodingInput) {
    if input.board >= 0.5 { raise(&levels, .publicBoardWork, by: 0.1) }
    if input.multi >= 0.5 { raise(&levels, .groupWork, by: 0.08) }
    if input.co >= 0.55 && input.board >= 0.4 { raise(&levels, .wholeClassInstruction, by: 0.08) }
}

private func applyTIMSSPreset(_ levels: inout [TIMSSActivityCode: Double], preset: TeachingSituationPreset) {
    for raw in preset.expectedTIMSSActivities {
        if let code = TIMSSActivityCode(rawValue: raw) {
            levels[code] = min(1, (levels[code] ?? 0) * 1.12 + 0.08)
        }
    }
    if preset.id == .frontalBoardInstruction,
       let wholeClass = levels[.wholeClassInstruction],
       let publicBoard = levels[.publicBoardWork],
       wholeClass == publicBoard {
        levels[.publicBoardWork] = publicBoard.nextDown
    }
}

private func raise(_ levels: inout [TIMSSActivityCode: Double], _ code: TIMSSActivityCode, by amount: Double) {
    levels[code] = min(1, (levels[code] ?? 0) + amount)
}

private func timssAssignment(
    code: TIMSSActivityCode,
    level: Double,
    input: PedagogicalCodingInput,
    preset: TeachingSituationPreset,
    confidence: Double
) -> PedagogicalCodeAssignment {
    PedagogicalCodeAssignment(
        .init(
            identity: .init(id: "timss-\(code.rawValue)", family: .timssActivityScript),
            descriptor: .init(code: code.rawValue, labelDE: code.titleDE),
            measurement: .init(level: level, confidence: confidence * (0.8 + 0.2 * level)),
            rationaleDE: "Abgeleitet aus Unterrichtsszene \(input.scene.titleDE), Strukturmerkmalen und Preset „\(preset.titleDE)“ (TIMSS-Skript-Proxy)."
        )
    )
}
