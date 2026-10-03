import Foundation
import GuidanceEngine
import SessionCore

extension PedagogicalCoder {
    static func codeIPN(
        input: PedagogicalCodingInput,
        preset: TeachingSituationPreset,
        focus: CodingAnalysisFocus?,
        confidence: Double
    ) -> [PedagogicalCodeAssignment] {
        guard input.scene != .emptyOrUnusable else { return [] }
        let levels = ipnLevels(input: input, preset: preset, focus: focus)
        return IPNDimensionCode.allCases.compactMap { code in
            guard let level = levels[code] else { return nil }
            return ipnAssignment(code: code, level: level, confidence: confidence, preset: preset)
        }
    }
}

private func ipnLevels(
    input: PedagogicalCodingInput,
    preset: TeachingSituationPreset,
    focus: CodingAnalysisFocus?
) -> [IPNDimensionCode: Double] {
    let support = ipnSupportLevel(input)
    let raw: [IPNDimensionCode: Double] = [
        .classroomOrganization: organizationLevel(input),
        .goalOrientation: 0.42 * input.board + 0.22 * input.co + 0.18 * ipnGoalScene(input.scene) + 0.18 * input.textDensity,
        .learningSupport: support,
        .cognitiveActivation: 0.30 * input.board + 0.20 * input.co + 0.24 * ipnCognitiveScene(input.scene) + 0.12 * input.people + 0.14 * input.textDensity,
        .socialClimate: socialLevel(input),
        .errorCulture: 0.42 * support + 0.38 * ipnErrorScene(input.scene) + 0.20 * input.people,
        .experimentation: experimentationLevel(input)
    ]
    return Dictionary(uniqueKeysWithValues: raw.map { code, value in
        (code, ipnBoost(code, preset: preset, focus: focus, raw: value))
    })
}

private func organizationLevel(_ input: PedagogicalCodingInput) -> Double {
    0.24 * input.interaction + 0.18 * input.stable + 0.14 * 0.75
        + 0.14 * min(1, Double(input.peopleN) / 3.0) + 0.10 * input.mid
        + 0.12 * organizationLayout(input.layout) + 0.08 * organizationScene(input.scene)
}

private func ipnSupportLevel(_ input: PedagogicalCodingInput) -> Double {
    0.32 * input.people + 0.28 * input.co + 0.22 * ipnSupportScene(input.scene)
        + 0.12 * input.mid + 0.06 * input.multi
}

private func socialLevel(_ input: PedagogicalCodingInput) -> Double {
    let layout = Set([ClassroomLayoutPattern.circleLike, .multiCluster]).contains(input.layout) ? 0.85
        : (input.layout == .dyadClose ? 0.5 : 0.35)
    return 0.26 * input.multi + 0.22 * input.people + 0.18 * input.mid
        + 0.16 * ipnSocialScene(input.scene) + 0.18 * layout
}

private func experimentationLevel(_ input: PedagogicalCodingInput) -> Double {
    let layout = input.layout == .sparseSpread ? 0.9 : (input.layout == .multiCluster ? 0.5 : 0.2)
    return 0.34 * ipnExperimentScene(input.scene) + 0.18 * input.multi + 0.14 * input.people
        + 0.12 * (1.0 - min(1, input.board)) + 0.08 * input.mid + 0.14 * layout
}

private func ipnBoost(_ code: IPNDimensionCode, preset: TeachingSituationPreset, focus: CodingAnalysisFocus?, raw: Double) -> Double {
    let presetFactor = preset.ipnEmphasis.contains(code.rawValue) ? 1.08 : 1.0
    let focusFactor = focus?.ipnBoosts.contains(code.rawValue) == true ? 1.06 : 1.0
    return min(1, raw * presetFactor * focusFactor)
}

private func ipnAssignment(
    code: IPNDimensionCode,
    level: Double,
    confidence: Double,
    preset: TeachingSituationPreset
) -> PedagogicalCodeAssignment {
    let identity = PedagogicalCodeAssignment.Identity(id: "ipn-\(code.rawValue)", family: .ipnProcessQuality)
    let descriptor = PedagogicalCodeAssignment.Descriptor(code: code.rawValue, labelDE: code.titleDE)
    let measurement = PedagogicalCodeAssignment.Measurement(level: level, confidence: confidence * (0.85 + 0.15 * level))
    let values = PedagogicalCodeAssignment.Values(identity: identity, descriptor: descriptor, measurement: measurement, rationaleDE: ipnRationale(code, preset: preset))
    return PedagogicalCodeAssignment(values)
}

private func ipnRationale(_ code: IPNDimensionCode, preset: TeachingSituationPreset) -> String {
    let rationales: [IPNDimensionCode: String] = [
        .classroomOrganization: "Struktur/Stabilität/Interaktionsabdeckung aus Platzierung und Akteuren; Preset-Prior \(preset.id.rawValue).",
        .goalOrientation: "Schreibflächen- und Co-Präsenzsignale als Proxy für Zielsichtbarkeit (IPN Zielklarheit).",
        .learningSupport: "Akteursdichte, Co-Präsenz und Dialog-/Gruppenszene (IPN Lernunterstützung).",
        .cognitiveActivation: "Tafelarbeit, Präsentation oder Experiment-Struktur als Aktivierungs-Proxy.",
        .socialClimate: "Mehrpersonen-, Plenum- und Mittelband-Signale (soziale Einbindung).",
        .errorCulture: "Proxy aus Dialog-/Unterstützungsmustern - nicht validierte Fehlerkodierung.",
        .experimentation: "IPN-Experimentierphase: verteilte Akteure, schwache Tafel, Hands-on-Struktur (Seidel et al. 2006)."
    ]
    return rationales[code] ?? "IPN-Strukturproxy."
}

private func organizationLayout(_ layout: ClassroomLayoutPattern) -> Double {
    let values: [ClassroomLayoutPattern: Double] = [
        .wholeRoomDense: 0.85, .frontalRows: 0.85, .multiCluster: 0.7, .circleLike: 0.7,
        .sparseSpread: 0.55, .seatworkScattered: 0.55, .presentationFocus: 0.6, .dyadClose: 0.6
    ]
    return values[layout] ?? 0.4
}

private func organizationScene(_ scene: TeachingSceneType) -> Double {
    Set([TeachingSceneType.wholeRoomOverview, .boardCentricFrontal, .transitionMoment]).contains(scene) ? 0.85 : 0.4
}

private func ipnGoalScene(_ scene: TeachingSceneType) -> Double {
    let values: [TeachingSceneType: Double] = [
        .boardCentricFrontal: 0.88, .studentAtBoard: 0.88, .teacherDemonstration: 0.88,
        .boardOnly: 0.55, .dialoguePair: 0.45, .transitionMoment: 0.25, .individualSeatwork: 0.3
    ]
    return values[scene] ?? 0.28
}

private func ipnSupportScene(_ scene: TeachingSceneType) -> Double {
    let values: [TeachingSceneType: Double] = [
        .dialoguePair: 0.8, .multiPersonGroup: 0.8, .circleDiscussion: 0.8,
        .boardCentricFrontal: 0.55, .studentAtBoard: 0.55, .teacherDemonstration: 0.55,
        .experimentSpread: 0.62, .actorsWithoutBoard: 0.62, .individualSeatwork: 0.62,
        .wholeRoomOverview: 0.45, .transitionMoment: 0.45
    ]
    return values[scene] ?? 0.22
}

private func ipnCognitiveScene(_ scene: TeachingSceneType) -> Double {
    let values: [TeachingSceneType: Double] = [
        .studentAtBoard: 0.82, .boardCentricFrontal: 0.82, .teacherDemonstration: 0.82,
        .experimentSpread: 0.8, .dialoguePair: 0.55, .multiPersonGroup: 0.52,
        .individualSeatwork: 0.52, .circleDiscussion: 0.48, .transitionMoment: 0.22
    ]
    return values[scene] ?? 0.18
}

private func ipnSocialScene(_ scene: TeachingSceneType) -> Double {
    let values: [TeachingSceneType: Double] = [
        .circleDiscussion: 0.92, .multiPersonGroup: 0.85, .dialoguePair: 0.55,
        .wholeRoomOverview: 0.5, .transitionMoment: 0.5, .individualSeatwork: 0.35
    ]
    return values[scene] ?? 0.28
}

private func ipnErrorScene(_ scene: TeachingSceneType) -> Double {
    let values: [TeachingSceneType: Double] = [
        .dialoguePair: 0.75, .circleDiscussion: 0.75, .multiPersonGroup: 0.45,
        .boardCentricFrontal: 0.35, .studentAtBoard: 0.35, .teacherDemonstration: 0.35,
        .individualSeatwork: 0.25
    ]
    return values[scene] ?? 0.2
}

private func ipnExperimentScene(_ scene: TeachingSceneType) -> Double {
    let values: [TeachingSceneType: Double] = [
        .experimentSpread: 0.92, .multiPersonGroup: 0.48, .actorsWithoutBoard: 0.42,
        .individualSeatwork: 0.42, .wholeRoomOverview: 0.35, .transitionMoment: 0.35,
        .boardCentricFrontal: 0.18, .studentAtBoard: 0.18, .teacherDemonstration: 0.18,
        .dialoguePair: 0.22, .circleDiscussion: 0.22
    ]
    return values[scene] ?? 0.12
}
