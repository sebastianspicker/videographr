import Foundation

extension GuidanceEngine {
    public func evaluateOrientation(_ o: OrientationSample) -> [GuidanceTip] {
        orientationTips(o)
    }

    public func evaluateCeilingAndFloor(_ o: OrientationSample, frame: FrameMetrics) -> [GuidanceTip] {
        ceilingAndFloorTips(o, frame: frame)
    }

    public func evaluateBlackboard(frame: FrameMetrics, cv: CVFeatures = .empty) -> [GuidanceTip] {
        blackboardTips(frame: frame, cv: cv)
    }

    public func evaluateInteractionZone(
        _ o: OrientationSample,
        frame: FrameMetrics,
        cv: CVFeatures = .empty
    ) -> [GuidanceTip] {
        interactionZoneTips(o, frame: frame, cv: cv)
    }

    public func evaluateBacklight(_ frame: FrameMetrics) -> [GuidanceTip] {
        backlightTips(frame)
    }

    public func evaluateComposition(_ frame: FrameMetrics) -> [GuidanceTip] {
        compositionTips(frame)
    }

    public func evaluateExposureStructure(_ frame: FrameMetrics) -> [GuidanceTip] {
        exposureStructureTips(frame)
    }

    public func evaluatePeopleCV(_ cv: CVFeatures) -> [GuidanceTip] {
        peopleCVTips(cv)
    }

    public func evaluateMotion(_ motion: MotionMetrics) -> [GuidanceTip] {
        motionTips(motion)
    }

    func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded())) %"
    }
}
