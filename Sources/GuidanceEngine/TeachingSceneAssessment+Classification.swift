import Foundation

func classify(_ input: SceneInput) -> (TeachingSceneType, Double) {
    if !input.hasPeople { return input.hasBoard ? (.boardOnly, min(0.95, 0.55 + input.effectiveBoard * 0.4)) : (.emptyOrUnusable, 0.85) }
    if let layout = layoutCandidate(input) { return layout }
    return signalCandidate(input)
}

private func layoutCandidate(_ input: SceneInput) -> (TeachingSceneType, Double)? {
    let candidates: [ClassroomLayoutPattern: (TeachingSceneType, Double)] = [
        .frontalRows: (.boardCentricFrontal, 0.78),
        .presentationFocus: (.teacherDemonstration, 0.74),
        .dyadClose: (.dialoguePair, 0.74),
        .multiCluster: (.multiPersonGroup, 0.76),
        .circleLike: (.circleDiscussion, 0.8),
        .sparseSpread: (.experimentSpread, 0.72),
        .wholeRoomDense: (.wholeRoomOverview, 0.72),
        .seatworkScattered: (.individualSeatwork, 0.68)
    ]
    guard let candidate = candidates[input.layout], !ignoresLayoutCandidate(input) else { return nil }
    return adjustedLayoutCandidate(candidate, input: input)
}

private func ignoresLayoutCandidate(_ input: SceneInput) -> Bool {
    switch input.layout {
    case .frontalRows, .presentationFocus:
        return !input.hasBoard
    default:
        return false
    }
}
private func adjustedLayoutCandidate(
    _ candidate: (TeachingSceneType, Double),
    input: SceneInput
) -> (TeachingSceneType, Double) {
    guard input.layout == .presentationFocus else { return candidate }
    if input.preset.expectedScenes.contains(.studentAtBoard),
       let closeBoard = closeBoardCandidate(input) {
        return closeBoard
    }
    return input.preset.expectedScenes.contains(.teacherDemonstration)
        ? candidate : (.boardCentricFrontal, 0.72)
}

private func signalCandidate(_ input: SceneInput) -> (TeachingSceneType, Double) { closeBoardCandidate(input) ?? frontalCandidate(input) ?? circleCandidate(input) ?? groupCandidate(input) ?? remainingCandidate(input) }
private func closeBoardCandidate(_ input: SceneInput) -> (TeachingSceneType, Double)? { guard closeBoard(input) else { return nil }; return (.studentAtBoard, min(0.9, 0.48 + input.co * 0.3 + input.textDensity * 0.12)) }
private func closeBoard(_ input: SceneInput) -> Bool { input.hasBoard && input.peopleN <= 2 && input.co >= 0.55 }
private func frontalCandidate(_ input: SceneInput) -> (TeachingSceneType, Double)? { guard input.hasBoard && input.co >= 0.40 else { return nil }; return (.boardCentricFrontal, min(0.94, 0.52 + input.board * 0.22 + input.co * 0.22)) }
private func circleCandidate(_ input: SceneInput) -> (TeachingSceneType, Double)? { guard input.peopleN >= 4 && input.mid >= 0.65 else { return nil }; return (.circleDiscussion, min(0.88, 0.48 + input.mid * 0.4)) }
private func groupCandidate(_ input: SceneInput) -> (TeachingSceneType, Double)? { guard input.peopleN >= 3 else { return nil }; return (.multiPersonGroup, min(0.9, 0.5 + input.peopleSignal * 0.4)) }
private func remainingCandidate(_ input: SceneInput) -> (TeachingSceneType, Double) { input.peopleN == 2 ? (.dialoguePair, min(0.88, 0.5 + input.peopleSignal * 0.35)) : (.actorsWithoutBoard, min(0.85, 0.45 + input.peopleSignal * 0.4)) }
