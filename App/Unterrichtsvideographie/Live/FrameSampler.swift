import Foundation
import AVFoundation
import CoreImage
import GuidanceEngine

/// One analyzed video frame: luminance-grid metrics plus structure CV features.
struct LiveFrameAnalysis: Sendable {
    var metrics: FrameMetrics
    var cv: CVFeatures
}

/// Rate-limited bridge from `CMSampleBuffer` → pure `FrameMetrics` + `CVFeatures`.
///
/// Downscales for fast composition heuristics while running on-device Vision on the full buffer.
/// Keeps Vision/CI work out of `GuidanceEngine` so unit tests stay pure.
/// This object is confined to `CaptureSessionController`'s video callback queue.
/// It intentionally has no cross-queue sharing contract.
final class FrameSampler {
    private let analyzer = FrameAnalyzer()
    private let vision = VisionClassroomAnalyzer()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let targetWidth = 64
    private let targetHeight = 48
    private var lastProcessTime: CFTimeInterval = 0
    private let minInterval: CFTimeInterval = 0.35

    /// Analyze a video sample if enough time has elapsed since the last run (~2–3 Hz).
    /// - Returns: `nil` when rate-limited or the buffer has no image.
    func analyze(from sampleBuffer: CMSampleBuffer) -> LiveFrameAnalysis? {
        let now = CACurrentMediaTime()
        guard now - lastProcessTime >= minInterval else { return nil }
        lastProcessTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        // Vision on full-res buffer (also rate-limited inside VisionClassroomAnalyzer).
        let cv = vision.analyze(pixelBuffer: pixelBuffer)

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let scaleX = CGFloat(targetWidth) / ciImage.extent.width
        let scaleY = CGFloat(targetHeight) / ciImage.extent.height
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var raw = [UInt8](repeating: 0, count: targetWidth * targetHeight * 4)
        guard let cgSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        ciContext.render(
            scaled,
            toBitmap: &raw,
            rowBytes: targetWidth * 4,
            bounds: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
            format: .RGBA8,
            colorSpace: cgSpace
        )

        var luminance = [Double](repeating: 0, count: targetWidth * targetHeight)
        for i in 0..<(targetWidth * targetHeight) {
            let o = i * 4
            let r = Double(raw[o]) / 255.0
            let g = Double(raw[o + 1]) / 255.0
            let b = Double(raw[o + 2]) / 255.0
            luminance[i] = 0.299 * r + 0.587 * g + 0.114 * b
        }
        let metrics = analyzer.analyze(luminance: luminance, width: targetWidth, height: targetHeight)
        return LiveFrameAnalysis(metrics: metrics, cv: cv)
    }

    /// Back-compat helper used by some call sites.
    func metrics(from sampleBuffer: CMSampleBuffer) -> FrameMetrics? {
        analyze(from: sampleBuffer)?.metrics
    }

    /// Clear Vision temporal smoother / rate-limit state (session start or stop).
    func resetVisionTemporalState() {
        vision.resetTemporalState()
        lastProcessTime = 0
    }

    /// Align production Vision cadence with selected teaching-situation preset.
    func configureVision(for situation: TeachingSituationID) {
        vision.configure(for: situation)
    }
}
