import QuartzCore

/// Bounds full direct-guidance work while preserving immediate entry to and recovery from
/// critical orientation or unstable-motion states.
struct MotionGuidanceCadence {
    let minimumInterval: CFTimeInterval
    private(set) var lastRefreshAt: CFTimeInterval?
    private(set) var lastBoundary: Boundary?

    struct Boundary: Equatable {
        var orientationIsCritical: Bool
        var motionIsAcceptable: Bool
    }

    mutating func shouldRefresh(at time: CFTimeInterval, boundary: Boundary) -> Bool {
        let boundaryChanged = lastBoundary.map { $0 != boundary } ?? true
        let intervalElapsed = lastRefreshAt.map { time - $0 >= minimumInterval } ?? true
        guard boundaryChanged || intervalElapsed else { return false }
        lastRefreshAt = time
        lastBoundary = boundary
        return true
    }

    mutating func reset() {
        lastRefreshAt = nil
        lastBoundary = nil
    }
}
