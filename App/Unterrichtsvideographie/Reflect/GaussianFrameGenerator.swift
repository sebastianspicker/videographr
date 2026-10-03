import AVFoundation
import CoreGraphics
import CoreML
import CoreVideo
import ExperimentalResearch
import Foundation
import SessionCore

struct GaussianFrameRequest: Identifiable, Equatable, Sendable {
    let id = UUID()
    let sessionID: UUID
    let assetID: UUID
    let mediaURL: URL
    let time: CMTime
    let authorization: GaussianAuthorizationContext?

    init(sessionID: UUID, assetID: UUID, mediaURL: URL, time: CMTime,
         authorization: GaussianAuthorizationContext? = nil) {
        self.sessionID = sessionID
        self.assetID = assetID
        self.mediaURL = mediaURL
        self.time = time
        self.authorization = authorization
    }
}

/// Injectable seam verifies persistence and identity before freezing playback.
enum GaussianLaunchPreparation {
    struct Selection {
        let session: CaptureSession
        let assetID: UUID
        let mediaURL: URL
    }

    @MainActor
    static func prepare(
        selection: Selection,
        persist: () async -> Bool,
        currentSelection: () -> Selection?,
        freeze: () -> CMTime?
    ) async throws -> GaussianFrameRequest {
        try Task.checkCancellation()
        guard await persist() else { throw GaussianFrameError.persistenceUnavailable }
        try Task.checkCancellation()
        guard let current = currentSelection(),
              current.session.id == selection.session.id,
              current.assetID == selection.assetID, current.mediaURL == selection.mediaURL,
              current.session.mediaAssets.contains(where: { $0.id == current.assetID }),
              GaussianExplorationPolicy.permits(current.session)
        else { throw GaussianFrameError.staleRequest }
        guard let time = freeze() else { throw GaussianFrameError.playbackNotReady }
        return GaussianFrameRequest(
            sessionID: current.session.id, assetID: current.assetID,
            mediaURL: current.mediaURL, time: time,
            authorization: GaussianAuthorizationContext(session: current.session)
        )
    }
}

/// CGImage is immutable. This value only transfers a finished image and immutable geometry.
struct GaussianFrameResult: @unchecked Sendable {
    let sourceImage: CGImage
    let actualTime: CMTime
    let surface: GaussianDepthSurface
}

enum GaussianFrameError: LocalizedError {
    case modelUnavailable
    case unsupportedModel
    case invalidFrame
    case invalidDepth
    case persistenceUnavailable
    case staleRequest
    case playbackNotReady

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Diese App-Version enthält kein lokales Tiefenmodell. Die experimentelle Perspektivansicht ist deshalb nicht verfügbar."
        case .unsupportedModel:
            return "Das lokale Tiefenmodell hat ein nicht unterstütztes Ein- oder Ausgabeformat."
        case .invalidFrame:
            return "Für diese Position konnte kein gültiges Videostandbild gelesen werden."
        case .invalidDepth:
            return "Das Modell hat für dieses Standbild keine nutzbare relative Tiefenstruktur geliefert."
        case .persistenceUnavailable:
            return "Protokoll und Freigaben konnten nicht lokal gesichert werden. Bitte den Speicherfehler beheben und erneut versuchen."
        case .staleRequest:
            return "Aufnahme, Sitzung oder Freigabe hat sich geändert. Bitte die Auswahl prüfen und erneut öffnen."
        case .playbackNotReady:
            return "Bitte warten, bis das Video und die gewählte Zeitposition bereit sind, und erneut versuchen."
        }
    }
}

enum GaussianGenerationStage: Sendable {
    case waiting, extractingFrame, preparingModel, estimatingDepth, buildingScene

    var title: String {
        switch self {
        case .waiting: return "Lokale Berechnung wird vorbereitet…"
        case .extractingFrame: return "Standbild wird aus der Aufnahme gelesen…"
        case .preparingModel: return "Lokales Tiefenmodell wird vorbereitet…"
        case .estimatingDepth: return "Relative Tiefe wird auf diesem Gerät geschätzt…"
        case .buildingScene: return "Perspektivansicht wird aufgebaut…"
        }
    }
}

enum GaussianFrameGenerator {
    private static let gate = GaussianGenerationGate()
    private static let models = GaussianModelCache()

    static var bundledModelURL: URL? {
        Bundle.main.url(forResource: "DepthAnythingV2SmallF16", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "DepthAnythingV2SmallF16", withExtension: "mlpackage")
    }

    /// Releases the loaded model; the next generation reloads it from the compiled copy.
    static func discardCachedModel() {
        models.removeLoadedModels()
    }

    /// Extraction, compilation, inference and geometry execute outside the main actor.
    /// Cancellation suppresses results even when native Core ML work is in flight.
    static func generate(
        _ request: GaussianFrameRequest, modelURL: URL?,
        isAuthorized: @escaping @MainActor @Sendable () -> Bool = { true },
        onProgress: @escaping @Sendable (GaussianGenerationStage) async -> Void = { _ in }
    ) async throws -> GaussianFrameResult {
        guard let modelURL else { throw GaussianFrameError.modelUnavailable }
        await onProgress(.waiting)
        await gate.acquire()
        do {
            try Task.checkCancellation()
            guard await isAuthorized() else { throw CancellationError() }
            let worker = Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                await onProgress(.extractingFrame)
                try Task.checkCancellation()
                guard await isAuthorized() else { throw CancellationError() }
                // Model preparation reads no recording data, so it overlaps frame extraction.
                // Core ML loading ignores cancellation; an early exit still awaits it while
                // holding the gate, and the loaded model stays cached for the next request.
                async let preparedModel = loadModel(at: modelURL)
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: request.mediaURL))
                generator.appliesPreferredTrackTransform = true
                generator.requestedTimeToleranceBefore = .zero
                generator.requestedTimeToleranceAfter = .zero
                generator.maximumSize = CGSize(width: 1280, height: 1280)
                let frame = try await generator.image(at: request.time)
                try Task.checkCancellation()
                guard frame.image.width > 1, frame.image.height > 1,
                      frame.actualTime.isNumeric, frame.actualTime.seconds.isFinite
                else { throw GaussianFrameError.invalidFrame }
                await onProgress(.preparingModel)
                let model = try await preparedModel.model
                try Task.checkCancellation()
                guard let constraint = model.modelDescription.inputDescriptionsByName["image"]?.imageConstraint,
                      constraint.pixelsWide > 1, constraint.pixelsHigh > 1,
                      constraint.pixelsWide <= 4096, constraint.pixelsHigh <= 4096,
                      constraint.pixelFormatType == kCVPixelFormatType_32BGRA
                else { throw GaussianFrameError.unsupportedModel }
                let input = try makeImageBuffer(frame.image, constraint: constraint)
                let features = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: input)])
                try Task.checkCancellation()
                await onProgress(.estimatingDepth)
                try Task.checkCancellation()
                guard await isAuthorized() else { throw CancellationError() }
                let prediction = try await model.prediction(from: features)
                try Task.checkCancellation()
                guard let depth = prediction.featureValue(for: "depth")?.imageBufferValue else {
                    throw GaussianFrameError.unsupportedModel
                }
                await onProgress(.buildingScene)
                let aspect = Float(frame.image.width) / Float(frame.image.height)
                guard (0.1...10).contains(aspect) else { throw GaussianFrameError.invalidFrame }
                let width = max(2, Int(sqrt(Float(GaussianDepthSurface.maximumPointCount) * aspect)))
                let height = max(2, min(Int(Float(width) / aspect), GaussianDepthSurface.maximumPointCount / width))
                let colors = try sampleColors(frame.image, width: width, height: height)
                let samples = try sampleDepth(depth, width: width, height: height)
                try Task.checkCancellation()
                let surface: GaussianDepthSurface
                do {
                    surface = try GaussianDepthSurface.make(
                        width: width, height: height, rgba: colors, inverseDepth: samples, aspectRatio: aspect
                    )
                } catch { throw GaussianFrameError.invalidDepth }
                try Task.checkCancellation()
                return GaussianFrameResult(sourceImage: frame.image, actualTime: frame.actualTime, surface: surface)
            }
            let result = try await withTaskCancellationHandler {
                let result = try await worker.value
                try Task.checkCancellation()
                return result
            } onCancel: {
                worker.cancel()
            }
            await gate.release()
            return result
        } catch {
            await gate.release()
            throw error
        }
    }

    /// Compiles a package once per process and reuses the loaded model while memory allows.
    private static func loadModel(at modelURL: URL) async throws -> GaussianLoadedModel {
        if let cached = models.model(for: modelURL) { return cached }
        let loadURL: URL
        if modelURL.pathExtension == "mlmodelc" {
            loadURL = modelURL
        } else if let compiled = models.compiledModel(for: modelURL) {
            loadURL = compiled
        } else {
            loadURL = try await MLModel.compileModel(at: modelURL)
            models.insertCompiled(loadURL, for: modelURL)
        }
        let configuration = MLModelConfiguration()
        #if targetEnvironment(simulator)
        // Simulator accelerator backends can return a zero depth image
        // without an inference error. Use the validated CPU path there;
        // physical devices retain their available hardware acceleration.
        configuration.computeUnits = .cpuOnly
        #else
        configuration.computeUnits = .all
        #endif
        let loaded = GaussianLoadedModel(model: try await MLModel.load(contentsOf: loadURL, configuration: configuration))
        models.insert(loaded, for: modelURL)
        return loaded
    }

    private static func makeImageBuffer(_ image: CGImage, constraint: MLImageConstraint) throws -> CVPixelBuffer {
        var optionalBuffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        guard CVPixelBufferCreate(
            kCFAllocatorDefault, constraint.pixelsWide, constraint.pixelsHigh,
            constraint.pixelFormatType, attributes, &optionalBuffer
        ) == kCVReturnSuccess, let buffer = optionalBuffer
        else { throw GaussianFrameError.invalidFrame }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer), width: constraint.pixelsWide,
            height: constraint.pixelsHigh, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { throw GaussianFrameError.invalidFrame }
        // Explicit stretch: depth UVs and colour UVs always refer to the entire same frame.
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: constraint.pixelsWide, height: constraint.pixelsHigh))
        return buffer
    }

    private static func sampleColors(_ image: CGImage, width: Int, height: Int) throws -> [UInt8] {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        try rgba.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { throw GaussianFrameError.invalidFrame }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return rgba
    }

    private static func sampleDepth(_ buffer: CVPixelBuffer, width: Int, height: Int) throws -> [Float] {
        let format = CVPixelBufferGetPixelFormatType(buffer)
        guard format == kCVPixelFormatType_OneComponent16Half || format == kCVPixelFormatType_OneComponent32Float,
              CVPixelBufferGetWidth(buffer) > 1, CVPixelBufferGetHeight(buffer) > 1,
              !CVPixelBufferIsPlanar(buffer)
        else { throw GaussianFrameError.unsupportedModel }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw GaussianFrameError.invalidDepth }
        let depthWidth = CVPixelBufferGetWidth(buffer)
        let depthHeight = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        let isHalf = format == kCVPixelFormatType_OneComponent16Half
        let columns = (0..<width).map { column in
            min(depthWidth - 1, Int((Float(column) + 0.5) / Float(width) * Float(depthWidth)))
        }
        var samples: [Float] = []
        samples.reserveCapacity(width * height)
        for row in 0..<height {
            try Task.checkCancellation()
            let depthRow = min(depthHeight - 1, Int((Float(row) + 0.5) / Float(height) * Float(depthHeight)))
            let rowBase = base + depthRow * stride
            if isHalf {
                let values = rowBase.assumingMemoryBound(to: Float16.self)
                for column in columns { samples.append(Float(values[column])) }
            } else {
                let values = rowBase.assumingMemoryBound(to: Float.self)
                for column in columns { samples.append(values[column]) }
            }
        }
        return samples
    }
}

/// The generation gate admits one pipeline at a time, so a cached model is never
/// used concurrently even though Core ML types are not declared Sendable.
private struct GaussianLoadedModel: @unchecked Sendable {
    let model: MLModel
}

/// NSCache drops the loaded model under memory pressure. The compiled copy stays on
/// disk for the process lifetime so a reload skips compilation.
private final class GaussianModelCache: @unchecked Sendable {
    private final class Entry {
        let loaded: GaussianLoadedModel
        init(_ loaded: GaussianLoadedModel) { self.loaded = loaded }
    }

    private let loadedModels = NSCache<NSURL, Entry>()
    private let lock = NSLock()
    private var compiledModels: [URL: URL] = [:]

    func model(for source: URL) -> GaussianLoadedModel? {
        loadedModels.object(forKey: source as NSURL)?.loaded
    }

    func insert(_ loaded: GaussianLoadedModel, for source: URL) {
        loadedModels.setObject(Entry(loaded), forKey: source as NSURL)
    }

    func removeLoadedModels() {
        loadedModels.removeAllObjects()
    }

    func compiledModel(for source: URL) -> URL? {
        guard let compiled = lock.withLock({ compiledModels[source] }) else { return nil }
        // The system may purge temporary storage while the app keeps running.
        return FileManager.default.fileExists(atPath: compiled.path) ? compiled : nil
    }

    func insertCompiled(_ compiled: URL, for source: URL) {
        let replaced = lock.withLock { () -> URL? in
            defer { compiledModels[source] = compiled }
            return compiledModels[source]
        }
        // Only a Core ML-created temporary compilation is removed, never the source model.
        if let replaced, replaced != compiled { try? FileManager.default.removeItem(at: replaced) }
    }
}

/// One native pipeline at a time, including cancelled operations still finishing in Core ML.
/// Waiting cancellation is checked before starting work after the slot is granted.
private actor GaussianGenerationGate {
    private var occupied = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !occupied {
            occupied = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty {
            occupied = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
