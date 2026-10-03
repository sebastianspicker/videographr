import Foundation

extension GuidanceEngine {
    func evaluateOrientation(_ o: OrientationSample) -> [GuidanceTip] {
        orientationTips(o)
    }

    func evaluateCeilingAndFloor(_ o: OrientationSample, frame: FrameMetrics) -> [GuidanceTip] {
        ceilingAndFloorTips(o, frame: frame)
    }

    func evaluateBlackboard(frame: FrameMetrics, cv: CVFeatures = .empty) -> [GuidanceTip] {
        blackboardTips(frame: frame, cv: cv)
    }

    func evaluateBacklight(_ frame: FrameMetrics) -> [GuidanceTip] {
        backlightTips(frame)
    }

    func evaluateComposition(_ frame: FrameMetrics) -> [GuidanceTip] {
        compositionTips(frame)
    }

    func evaluateExposureStructure(_ frame: FrameMetrics) -> [GuidanceTip] {
        exposureStructureTips(frame)
    }

    func evaluatePeopleCV(_ cv: CVFeatures) -> [GuidanceTip] {
        peopleCVTips(cv)
    }

    func evaluateMotion(_ motion: MotionMetrics) -> [GuidanceTip] {
        motionTips(motion)
    }

    public func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded())) %"
    }
}
