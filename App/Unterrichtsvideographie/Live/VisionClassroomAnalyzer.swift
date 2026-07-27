import Foundation
import QuartzCore
import Vision
import CoreVideo
import GuidanceEngine

/// On-device Vision adapter. It only publishes measured structure; unsuccessful analysis is
/// explicitly marked rather than inferred from a previous frame.
final class VisionClassroomAnalyzer {
    private var lastRun: CFTimeInterval = 0
    private var minInterval: CFTimeInterval = 0.55
    private var lastFeatures = CVFeatures.empty
    private var smoother = CVObservationSmoother(alpha: 0.35)
    var teachingSituation: TeachingSituationID = .frontalBoardInstruction

    func configure(for situation: TeachingSituationID) {
        teachingSituation = situation
        minInterval = visionCadence(for: TeachingSituationCatalogue.preset(for: situation))
    }

    func analyze(pixelBuffer: CVPixelBuffer) -> CVFeatures {
        guard shouldAnalyzeNow() else { return lastFeatures }
        let requests = VisionRequests()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        guard performRequests(requests, with: handler) else { return failedFeatures() }

        let board = BoardObservation(requests: requests)
        let people = PeopleObservation(requests: requests)
        let layout = people.layout(board: board.rect, confidence: board.confidence)
        let raw = makeFeatures(board: board, people: people, layout: layout, saliency: requests.saliency.results?.first)
        var features = smoother.push(raw)
        if features.interactionDensity == 0 {
            features.interactionDensity = CVFeatureFusion.interactionDensity(from: features)
        }
        lastFeatures = features
        return features
    }

    func resetTemporalState() {
        smoother = CVObservationSmoother(alpha: 0.35)
        lastFeatures = .empty
        lastRun = 0
        configure(for: teachingSituation)
    }

    private func shouldAnalyzeNow() -> Bool {
        let now = CACurrentMediaTime()
        guard now - lastRun >= minInterval else { return false }
        lastRun = now
        return true
    }

    private func performRequests(_ requests: VisionRequests, with handler: VNImageRequestHandler) -> Bool {
        for set in [requests.full, requests.mid, requests.core] {
            if (try? handler.perform(set)) != nil { return true }
        }
        return false
    }

    private func failedFeatures() -> CVFeatures {
        // This is the `analysisSucceeded: false` fail-closed outcome of the Vision adapter.
        let failed = CVFeatures.make {
            $0.source = .vision
            $0.observationStability = lastFeatures.observationStability
            $0.analysisSucceeded = false
        }
        lastFeatures = failed
        return failed
    }

    private func makeFeatures(
        board: BoardObservation,
        people: PeopleObservation,
        layout: ClassroomLayoutMetrics,
        saliency: VNObservation?
    ) -> CVFeatures {
        let (midBand, centroid) = (people.midBand, people.centroid)
        let saliencyPeopleOverlap = people.saliencyOverlap(saliency)
        let secondaryBoardSupport = board.secondarySupport
        let coPresence = min(1, CVFeatureFusion.coPresence(
            board: board.rect,
            boardConfidence: board.confidence,
            personRects: people.rects,
            personCoverage: people.coverage
        ) + 0.08 * saliencyPeopleOverlap)
        let elevatedGesture = people.elevatedGesture(near: board.rect)
        let faceScale = min(1, layout.faceScaleScore + people.poseScaleBoost + 0.08 * elevatedGesture)
        let finalLayout = people.presentationLayout(
            layout,
            boardConfidence: board.confidence,
            elevatedGesture: elevatedGesture,
            faceScale: faceScale
        )
        let features = CVFeatures.make {
            $0.source = .vision
            $0.boardConfidence = board.confidence
            $0.boardRect = board.rect
            $0.boardAspectQuality = board.aspectQuality
            $0.boardGeometryQuality = board.geometryQuality
            $0.boardEdgeSupport = board.edgeSupport
            $0.personCount = people.count
            $0.personCoverage = people.coverage
            $0.faceCount = people.faceCount
            $0.personMidBandOccupancy = midBand
            $0.personCentroidY = centroid?.y
            $0.personCentroidX = centroid?.x
            $0.personBoardCoPresence = coPresence
            $0.personHorizontalSpread = finalLayout.horizontalSpread
            $0.personVerticalSpread = finalLayout.verticalSpread
            $0.personClusteredness = finalLayout.clusteredness
            $0.estimatedClusterCount = finalLayout.estimatedClusterCount
            $0.layoutPattern = finalLayout.pattern
            $0.faceScaleScore = faceScale
            $0.boardTextDensity = board.textSupport
            $0.secondaryWritingSurfaceSupport = secondaryBoardSupport
            $0.actorScaleVariance = CVFeatureFusion.actorScaleVariance(personRects: people.rects)
            $0.poseConfidenceMean = people.poseConfidenceMean
        }
        return finalizedFeatures(features, elevatedGesture: elevatedGesture, saliencyPeopleOverlap: saliencyPeopleOverlap)
    }
}

private func finalizedFeatures(
    _ features: CVFeatures,
    elevatedGesture: Double,
    saliencyPeopleOverlap: Double
) -> CVFeatures {
    var finalized = features
    finalized.interactionDensity = min(
        1,
        CVFeatureFusion.interactionDensity(from: finalized) + 0.12 * elevatedGesture + 0.10 * saliencyPeopleOverlap
    )
    return finalized
}

private func visionCadence(for preset: TeachingSituationPreset) -> CFTimeInterval {
    if preset.prefersMultiPerson { return 0.45 }
    if preset.minPeople >= 3 { return 0.45 }
    if preset.requiresBoard { return 0.55 }
    return 0.50
}

final class VisionRequests {
    let rectangles = VNDetectRectanglesRequest()
    let humans = VNDetectHumanRectanglesRequest()
    let faces = VNDetectFaceRectanglesRequest()
    let documents = VNDetectDocumentSegmentationRequest()
    let saliency = VNGenerateAttentionBasedSaliencyImageRequest()
    let text = VNRecognizeTextRequest()
    let pose = VNDetectHumanBodyPoseRequest()

    init() {
        rectangles.maximumObservations = 12
        rectangles.minimumConfidence = 0.35
        rectangles.minimumAspectRatio = 0.35
        rectangles.maximumAspectRatio = 4.0
        rectangles.minimumSize = 0.10
        text.recognitionLevel = .fast
        text.usesLanguageCorrection = false
        text.minimumTextHeight = 0.015
    }

    var core: [VNRequest] { [rectangles, humans, faces] }
    var mid: [VNRequest] { core + [documents, text] }
    var full: [VNRequest] { mid + [saliency, pose] }
}

private struct BoardObservation {
    var rect: ImageNormalizedRect?
    var confidence = 0.0
    var aspectQuality = 0.0
    var geometryQuality = 0.0
    var textSupport = 0.0
    var secondarySupport = 0.0
    var edgeSupport = 0.0

    init(requests: VisionRequests) {
        let candidates = (requests.rectangles.results ?? []).map { observation in
            let rect = visionTopLeft(observation.boundingBox)
            let aspect = CVFeatureFusion.boardAspectQuality(for: rect)
            let geometry = CVFeatureFusion.boardGeometryQuality(for: rect)
            return VisionRectangleCandidate(
                rect: rect,
                confidence: Double(observation.confidence),
                aspectQuality: aspect,
                geometryQuality: geometry
            )
        }.sorted { lhs, rhs in lhs.confidence * lhs.rect.area > rhs.confidence * rhs.rect.area }
        applyRectangleCandidate(candidates.first, candidates: candidates)
        incorporateDocument(requests.documents.results?.first)
        let textRects = (requests.text.results ?? []).compactMap { observation -> ImageNormalizedRect? in
            observation.confidence >= 0.25 ? visionTopLeft(observation.boundingBox) : nil
        }
        textSupport = CVFeatureFusion.boardTextSupport(board: rect, textRects: textRects)
        if rect == nil, let cluster = visionTextCluster(textRects), textSupport >= 0.45 {
            rect = cluster
            aspectQuality = CVFeatureFusion.boardAspectQuality(for: cluster)
            geometryQuality = CVFeatureFusion.boardGeometryQuality(for: cluster)
            confidence = min(0.62, 0.35 + 0.4 * textSupport)
        } else if textSupport > 0.35 {
            confidence = min(1, confidence + 0.06 * textSupport)
        }
        edgeSupport = CVFeatureFusion.fuseBoardEdgeSupport(
            documentOverlap: documentOverlap(requests.documents.results?.first),
            saliencyOverlap: saliencyOverlap(requests.saliency.results?.first),
            textSupport: textSupport,
            geometryFallback: 0.15 * geometryQuality + 0.1 * aspectQuality + 0.12 * secondarySupport
        )
    }

    private mutating func applyRectangleCandidate(
        _ candidate: VisionRectangleCandidate?,
        candidates: [VisionRectangleCandidate]
    ) {
        guard let candidate else { return }
        rect = candidate.rect
        aspectQuality = candidate.aspectQuality
        geometryQuality = candidate.geometryQuality
        confidence = min(1, candidate.confidence * 0.65 + candidate.aspectQuality * 0.2 + candidate.geometryQuality * 0.15)
        secondarySupport = candidates.dropFirst().prefix(3).reduce(0) { best, next in
            max(best, visionSecondarySupport(candidate: candidate, next: next))
        }
    }

    private mutating func incorporateDocument(_ observation: VNObservation?) {
        guard let observation, let document = visionDocumentRect(observation) else { return }
        let documentConfidence = (observation as? VNDetectedObjectObservation).map { Double($0.confidence) }
            ?? (observation as? VNRectangleObservation).map { Double($0.confidence) } ?? 0
        guard rect == nil, documentConfidence >= 0.30 else { return }
        rect = document
        aspectQuality = CVFeatureFusion.boardAspectQuality(for: document)
        geometryQuality = CVFeatureFusion.boardGeometryQuality(for: document)
        confidence = min(1, documentConfidence * 0.7 + aspectQuality * 0.15 + geometryQuality * 0.15)
    }

    private func documentOverlap(_ observation: VNObservation?) -> Double {
        guard let rect, let observation, let document = visionDocumentRect(observation) else { return 0 }
        return min(1, 0.35 + 0.55 * rect.iou(with: document))
    }

    private func saliencyOverlap(_ observation: VNObservation?) -> Double {
        guard let rect, let saliency = observation as? VNSaliencyImageObservation else { return 0 }
        let best = (saliency.salientObjects ?? []).map { rect.iou(with: visionTopLeft($0.boundingBox)) }.max() ?? 0
        return min(1, 0.25 + 0.7 * best)
    }
}

private struct VisionRectangleCandidate {
    let rect: ImageNormalizedRect
    let confidence: Double
    let aspectQuality: Double
    let geometryQuality: Double
}

func visionTopLeft(_ boundingBox: CGRect) -> ImageNormalizedRect {
    ImageNormalizedRect(
        x: Double(boundingBox.origin.x),
        y: 1 - Double(boundingBox.origin.y + boundingBox.height),
        width: Double(boundingBox.width),
        height: Double(boundingBox.height)
    )
}

private func visionDocumentRect(_ observation: VNObservation) -> ImageNormalizedRect? {
    if let rectangle = observation as? VNRectangleObservation { return visionTopLeft(rectangle.boundingBox) }
    if let detected = observation as? VNDetectedObjectObservation { return visionTopLeft(detected.boundingBox) }
    return nil
}

private func visionSecondarySupport(
    candidate: VisionRectangleCandidate,
    next: VisionRectangleCandidate
) -> Double {
    guard next.rect.iou(with: candidate.rect) < 0.35 else { return 0 }
    return min(0.45, next.confidence * next.rect.area)
}

private func visionTextCluster(_ rects: [ImageNormalizedRect]) -> ImageNormalizedRect? {
    guard rects.count >= 2 else { return nil }
    let minX = rects.map(\.x).min() ?? 0
    let minY = rects.map(\.y).min() ?? 0
    let maxX = rects.map { $0.x + $0.width }.max() ?? 0
    let maxY = rects.map { $0.y + $0.height }.max() ?? 0
    guard maxX - minX > 0.08, maxY - minY > 0.04, (maxX - minX) * (maxY - minY) <= 0.65 else { return nil }
    return ImageNormalizedRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}
