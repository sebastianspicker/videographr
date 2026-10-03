import AVFoundation
import ExperimentalResearch
import Foundation

private actor StageBarrier {
    private var reached = false
    private var released = false
    private var observers: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func signal() {
        reached = true
        observers.forEach { $0.resume() }
        observers.removeAll()
    }

    func waitUntilReached() async {
        if reached { return }
        await withCheckedContinuation { observers.append($0) }
    }

    func hold() async {
        signal()
        if released { return }
        await withCheckedContinuation { releaseContinuation = $0 }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

@MainActor private final class QueuedAuthorization { var permits = true }

@main
struct Smoke {
    @MainActor static func main() async throws {
        let request = GaussianFrameRequest(sessionID: UUID(), assetID: UUID(),
            mediaURL: URL(fileURLWithPath: CommandLine.arguments[2]),
            time: CMTime(value: 12, timescale: 30))
        let model = URL(fileURLWithPath: CommandLine.arguments[1])
        precondition(CommandLine.arguments.count == 5, "Expected model, portrait, landscape and widescreen fixtures")
        let result = try await GaussianFrameGenerator.generate(request, modelURL: model)
        precondition(result.sourceImage.width == 240 && result.sourceImage.height == 320)
        precondition(abs(result.actualTime.seconds - 0.4) < 0.00001)
        precondition(abs(result.surface.aspectRatio - 0.75) < 0.00001)
        precondition((19_000...20_000).contains(result.surface.points.count))
        precondition(result.surface.points.allSatisfy { (0.8...1.5).contains($0.z) && $0.sigma > 0 })
        let betweenFrames = GaussianFrameRequest(sessionID: request.sessionID, assetID: request.assetID,
            mediaURL: request.mediaURL, time: CMTime(seconds: 0.415, preferredTimescale: 600))
        let nonAligned = try await GaussianFrameGenerator.generate(betweenFrames, modelURL: model)
        precondition(abs(nonAligned.actualTime.seconds - 0.415) < 1.0 / 30.0)
        do {
            _ = try await GaussianFrameGenerator.generate(request, modelURL: nil)
            fatalError("Missing model accepted")
        } catch GaussianFrameError.modelUnavailable { }
        let cancelled = Task { try await GaussianFrameGenerator.generate(request, modelURL: model) }
        cancelled.cancel()
        do { _ = try await cancelled.value; fatalError("Cancelled result published") }
        catch is CancellationError { }
        let inFlight = Task { try await GaussianFrameGenerator.generate(request, modelURL: model) }
        try await Task.sleep(for: .milliseconds(10))
        let queued = Task { try await GaussianFrameGenerator.generate(request, modelURL: model) }
        let surviving = Task { try await GaussianFrameGenerator.generate(request, modelURL: model) }
        inFlight.cancel()
        queued.cancel()
        do { _ = try await inFlight.value; fatalError("Cancelled in-flight result published") } catch { }
        do { _ = try await queued.value; fatalError("Cancelled queued result published") } catch { }
        let survivingResult = try await surviving.value
        precondition(survivingResult.surface.points.count == result.surface.points.count)
        print("PASS: production pipeline extracted exact 0.4s rotated portrait frame, inferred depth, created", result.surface.points.count, "Gaussians, rejected missing model and cancellation")
        print("PASS: cancellation stress suppresses results and allows a surviving request")
        print("PASS: non-frame-aligned pause time 0.415s extracts frame at", nonAligned.actualTime.seconds)

        // Hold a known pipeline phase, rather than relying on scheduler timing.
        // This tests cancellation AFTER inference, not interruption inside Core ML.
        let held = StageBarrier()
        let waiting = StageBarrier()
        let authorization = QueuedAuthorization()
        let active = Task {
            try await GaussianFrameGenerator.generate(request, modelURL: model, onProgress: { stage in
                if stage == .buildingScene { await held.hold() }
            })
        }
        await held.waitUntilReached()
        let revoked = Task {
            try await GaussianFrameGenerator.generate(request, modelURL: model,
                isAuthorized: { authorization.permits }, onProgress: { stage in
                    if stage == .waiting { await waiting.signal() }
                    precondition(stage == .waiting, "Revoked queued request entered native processing")
                })
        }
        await waiting.waitUntilReached()
        authorization.permits = false
        active.cancel()
        await held.release()
        do { _ = try await active.value; fatalError("Canceled post-inference result published") }
        catch is CancellationError { }
        do { _ = try await revoked.value; fatalError("Revoked queued result published") }
        catch is CancellationError { }
        let recovered = try await GaussianFrameGenerator.generate(request, modelURL: model)
        precondition(recovered.surface == result.surface)
        print("PASS: deterministic post-inference cancellation, queued revocation before extraction, and gate recovery")

        // Additional orientations/aspects exercise real inference without repeating race tests.
        for (index, width, height, label) in [(3, 320, 240, "landscape 4:3"), (4, 384, 216, "landscape 16:9")] {
            let fixture = GaussianFrameRequest(sessionID: UUID(), assetID: UUID(),
                mediaURL: URL(fileURLWithPath: CommandLine.arguments[index]),
                time: CMTime(value: 12, timescale: 30))
            let generated = try await GaussianFrameGenerator.generate(fixture, modelURL: model)
            validate(generated, width: width, height: height, label: label)
        }
    }

    private static func validate(_ result: GaussianFrameResult, width: Int, height: Int, label: String) {
        precondition(result.sourceImage.width == width && result.sourceImage.height == height)
        precondition(abs(result.actualTime.seconds - 0.4) < 0.00001)
        precondition(abs(result.surface.aspectRatio - Float(width) / Float(height)) < 0.00001)
        precondition((19_000...GaussianDepthSurface.maximumPointCount).contains(result.surface.points.count))
        precondition(result.surface.points.allSatisfy {
            $0.x.isFinite && $0.y.isFinite && $0.z.isFinite && (0.8...1.5).contains($0.z)
                && $0.sigma.isFinite && $0.sigma > 0
                && $0.red.isFinite && $0.green.isFinite && $0.blue.isFinite
                && (0...1).contains($0.red) && (0...1).contains($0.green) && (0...1).contains($0.blue)
        })
        for camera in [GaussianCamera(), GaussianCamera(horizontal: 0.08, dolly: 0.06),
                       GaussianCamera(yawDegrees: 5, pitchDegrees: -4)] {
            let projected = GaussianProjection.project(result.surface, camera: camera)
            precondition(!projected.isEmpty)
            precondition(projected.allSatisfy {
                $0.x.isFinite && $0.y.isFinite && $0.cameraDepth.isFinite && $0.cameraDepth > 0
                    && $0.sigmaX.isFinite && $0.sigmaY.isFinite && $0.sigmaX > 0 && $0.sigmaY > 0
            })
            precondition(projected.map(\.cameraDepth) == projected.map(\.cameraDepth).sorted(by: >))
        }

        // Compare backprojected colour samples with the original oriented image's UVs.
        // This independently checks aspect/colour association, allowing resampling at edges.
        var reference = [UInt8](repeating: 0, count: width * height * 4)
        reference.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(result.sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let tangent = tan(GaussianDepthSurface.verticalFieldOfViewDegrees * .pi / 360)
        var difference: Float = 0
        for point in result.surface.points {
            let u = (point.x / (point.z * tangent * result.surface.aspectRatio) + 1) / 2
            let v = (1 - point.y / (point.z * tangent)) / 2
            let column = min(width - 1, max(0, Int(u * Float(width))))
            let row = min(height - 1, max(0, Int(v * Float(height))))
            let offset = (row * width + column) * 4
            difference += abs(point.red - Float(reference[offset]) / 255)
                + abs(point.green - Float(reference[offset + 1]) / 255)
                + abs(point.blue - Float(reference[offset + 2]) / 255)
        }
        let colorError = difference / Float(result.surface.points.count * 3)
        precondition(colorError < 0.08, "Oriented source colour/aspect mismatch: \(colorError)")
        print("PASS:", label, "actual frame/time/aspect, finite inferred geometry/projection and source colour error", colorError)
    }
}
