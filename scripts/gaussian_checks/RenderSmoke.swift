import AVFoundation
import CoreGraphics
import ExperimentalResearch
import Foundation
import ImageIO
import Metal
import UniformTypeIdentifiers

struct GPUPoint { var positionOpacity, tangentU, tangentV, texture: SIMD4<Float> }
struct GPUView {
    var right, up, forward, position: SIMD4<Float>
    var scale: SIMD2<Float>
    var nearClip: Float
    var maximumSigma: Float
    var marksUncertainty: Float = 0
}

@main struct RenderSmoke {
    static func main() async throws {
        let request = GaussianFrameRequest(sessionID: UUID(), assetID: UUID(),
            mediaURL: URL(fileURLWithPath: CommandLine.arguments[2]),
            time: CMTime(value: 12, timescale: 30))
        let result = try await GaussianFrameGenerator.generate(request, modelURL: URL(fileURLWithPath: CommandLine.arguments[1]))
        let device = MTLCreateSystemDefaultDevice()!
        let file = try String(contentsOfFile: CommandLine.arguments[3], encoding: .utf8)
        let start = file.range(of: "#include <metal_stdlib>")!
        let end = file.range(of: "\"\"\"", range: start.upperBound..<file.endIndex)!
        let library = try await device.makeLibrary(source: String(file[start.lowerBound..<end.lowerBound]), options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "gaussianVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "gaussianFragment")
        let color = descriptor.colorAttachments[0]!
        color.pixelFormat = .bgra8Unorm
        color.isBlendingEnabled = true
        color.sourceRGBBlendFactor = .one
        color.destinationRGBBlendFactor = .oneMinusSourceAlpha
        color.sourceAlphaBlendFactor = .one
        color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        let pipeline = try await device.makeRenderPipelineState(descriptor: descriptor)
        let backgroundDescriptor = MTLRenderPipelineDescriptor()
        backgroundDescriptor.vertexFunction = library.makeFunction(name: "gaussianBackgroundVertex")
        backgroundDescriptor.fragmentFunction = library.makeFunction(name: "gaussianBackgroundFragment")
        backgroundDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        let backgroundPipeline = try await device.makeRenderPipelineState(descriptor: backgroundDescriptor)
        let width = 240, height = 320
        func makeSource(_ rgba: [UInt8], width: Int, height: Int) -> MTLTexture {
            let description = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
            description.usage = .shaderRead
            let texture = device.makeTexture(descriptor: description)!
            rgba.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 4) }
            return texture
        }
        // Same device-RGB, 8-bit, non-linear upload as the production renderer.
        let frame = result.sourceImage
        var frameBytes = [UInt8](repeating: 0, count: frame.width * frame.height * 4)
        frameBytes.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: frame.width, height: frame.height, bitsPerComponent: 8,
                bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.interpolationQuality = .high
            context.draw(frame, in: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        }
        let frameTexture = makeSource(frameBytes, width: frame.width, height: frame.height)
        var order: [UInt32] = []
        // Reuses the previous order like the production renderer, so reset also checks re-sorting.
        func render(_ camera: GaussianCamera, surface: GaussianDepthSurface? = nil, source: MTLTexture? = nil, reusing: Bool = true,
                    marksUncertainty: Float = 0) -> [UInt8] {
            let surface = surface ?? result.surface
            let points = surface.points.map { p in
                GPUPoint(positionOpacity: SIMD4(p.x, p.y, p.z, p.opacity), tangentU: SIMD4(p.tangentU, p.isOcclusionEdge ? 1 : 0),
                         tangentV: SIMD4(p.tangentV, p.sourceFootprintArea), texture: SIMD4(lowHalf: p.textureCenter, highHalf: p.textureStep))
            }
            let pointBuffer = points.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count)! }
            let frame = GaussianViewFrame(camera: camera)
            let drawOrder = GaussianProjection.drawOrder(surface, forward: frame.forward, reusing: reusing ? order : [])
            if reusing { order = drawOrder }
            let orderBuffer = drawOrder.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count)! }
            let tangent = GaussianProjection.tangent
            var view = GPUView(right: SIMD4(frame.right, 0), up: SIMD4(frame.up, 0),
                               forward: SIMD4(frame.forward, 0), position: SIMD4(frame.position, 1),
                               scale: SIMD2(1 / (tangent * surface.aspectRatio), 1 / tangent),
                               nearClip: GaussianProjection.nearClip, maximumSigma: GaussianProjection.maximumSigma,
                               marksUncertainty: marksUncertainty)
            let textureDescription = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            textureDescription.storageMode = .shared
            textureDescription.usage = [.renderTarget]
            let texture = device.makeTexture(descriptor: textureDescription)!
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = texture
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.055, green: 0.065, blue: 0.08, alpha: 1)
            let command = device.makeCommandQueue()!.makeCommandBuffer()!
            let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
            encoder.setRenderPipelineState(pipeline)
            encoder.setVertexBuffer(pointBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(orderBuffer, offset: 0, index: 1)
            encoder.setVertexBytes(&view, length: MemoryLayout<GPUView>.stride, index: 2)
            encoder.setFragmentTexture(source ?? frameTexture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: drawOrder.count)
            encoder.endEncoding()
            command.commit()
            command.waitUntilCompleted()
            precondition(command.status == .completed)
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            bytes.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0) }
            return bytes
        }
        let original = render(GaussianCamera())
        let shifted = render(GaussianCamera(horizontal: 0.08))
        let orbited = render(GaussianCamera(yawDegrees: 5, pitchDegrees: 4))
        let reset = render(GaussianCamera())
        let markedOriginal = render(GaussianCamera(), marksUncertainty: 1)
        precondition(reset == original, "Reset camera did not reproduce original render")
        // Sparse fixture: four separated Gaussians clamped to the maximum footprint. Pixel
        // colours at CPU-projected centres and two standard deviations along each projected
        // surface axis must match the analytic Gaussian and the bilinear source sample.
        let sparseColors: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255]
        let sparse = try GaussianDepthSurface.make(width: 2, height: 2, rgba: sparseColors,
            inverseDepth: [0, 1, 2, 3], aspectRatio: Float(width) / Float(height))
        let sparseCamera = GaussianCamera(horizontal: 0.03, dolly: 0.05, yawDegrees: 4, pitchDegrees: -3)
        let sparseImage = render(sparseCamera, surface: sparse, source: makeSource(sparseColors, width: 2, height: 2), reusing: false)
        let background: SIMD3<Float> = [0.055, 0.065, 0.08]
        func texel(_ column: Int, _ row: Int) -> SIMD3<Float> {
            let index = (min(1, max(0, row)) * 2 + min(1, max(0, column))) * 4
            return SIMD3(Float(sparseColors[index]), Float(sparseColors[index + 1]), Float(sparseColors[index + 2])) / 255
        }
        func bilinear(_ uv: SIMD2<Float>) -> SIMD3<Float> {
            let position = uv * 2 - 0.5
            let base = position.rounded(.down), fraction = position - base
            let column = Int(base.x), row = Int(base.y)
            let top = texel(column, row) * (1 - fraction.x) + texel(column + 1, row) * fraction.x
            let bottom = texel(column, row + 1) * (1 - fraction.x) + texel(column + 1, row + 1) * fraction.x
            return top * (1 - fraction.y) + bottom * fraction.y
        }
        for projected in GaussianProjection.project(sparse, camera: sparseCamera) {
            for local in [SIMD2<Float>(0, 0), SIMD2(2, 0), SIMD2(0, -2)] {
                let position = SIMD2(projected.x, projected.y) + local.x * projected.axisU + local.y * projected.axisV
                let column = Int((position.x + 1) / 2 * Float(width))
                let row = Int((1 - position.y) / 2 * Float(height))
                let pixel = (row * width + column) * 4
                let rendered = SIMD3(Float(sparseImage[pixel + 2]), Float(sparseImage[pixel + 1]), Float(sparseImage[pixel])) / 255
                let alpha = projected.point.opacity * exp(-0.5 * (local * local).sum())
                let color = bilinear(projected.point.textureCenter + local * projected.point.textureStep)
                let expected = color * alpha + background * (1 - alpha)
                precondition(abs(rendered - expected).max() < 0.05,
                             "GPU projection differs from CPU reference at \(local): \(rendered) vs \(expected)")
            }
        }
        var reference = [UInt8](repeating: 0, count: width * height * 4)
        reference.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)!
            context.draw(result.sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        func difference(_ lhs: [UInt8], _ rhs: [UInt8]) -> Double {
            var total: Double = 0
            for i in 0..<lhs.count where i % 4 != 3 { total += abs(Double(lhs[i]) - Double(rhs[i])) / 255 }
            return total / Double(width * height * 3)
        }
        let sourceError = difference(original, reference)
        let movement = difference(original, shifted)
        precondition(sourceError < 0.02, "Source view alignment/color mismatch: \(sourceError)")
        precondition(movement > 0.025, "Camera movement did not change rendered view")
        let orbitChange = difference(original, orbited)
        precondition(orbitChange > 0.001, "Orbit did not change rendered view")
        // The synthetic frame has no occlusion edge and stays under the stretch onset when
        // orbited, so the marking is exercised on the sparse fixture, which has both.
        let markedSparse = render(sparseCamera, surface: sparse, source: makeSource(sparseColors, width: 2, height: 2),
                                  reusing: false, marksUncertainty: 1)
        let markingChange = difference(sparseImage, markedSparse)
        precondition(markingChange > 0.0005, "Uncertainty marking did not change the sparse render: \(markingChange)")
        let markedOrbit = render(GaussianCamera(yawDegrees: 5, pitchDegrees: 4), marksUncertainty: 1)
        precondition(difference(orbited, markedOrbit) < 0.05, "Uncertainty marking changed the orbited view too much")
        let markedSourceChange = difference(original, markedOriginal)
        precondition(markedSourceChange < 0.05, "Uncertainty marking changed the source view too much: \(markedSourceChange)")
        // The hatched background alone must show at least two distinct colours.
        func renderHatch() -> [UInt8] {
            let hatchDescription = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            hatchDescription.storageMode = .shared
            hatchDescription.usage = [.renderTarget]
            let hatchTexture = device.makeTexture(descriptor: hatchDescription)!
            let hatchPass = MTLRenderPassDescriptor()
            hatchPass.colorAttachments[0].texture = hatchTexture
            hatchPass.colorAttachments[0].loadAction = .clear
            hatchPass.colorAttachments[0].storeAction = .store
            let hatchCommand = device.makeCommandQueue()!.makeCommandBuffer()!
            let hatchEncoder = hatchCommand.makeRenderCommandEncoder(descriptor: hatchPass)!
            var period: Float = 10
            hatchEncoder.setRenderPipelineState(backgroundPipeline)
            hatchEncoder.setFragmentBytes(&period, length: MemoryLayout<Float>.stride, index: 0)
            hatchEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            hatchEncoder.endEncoding()
            hatchCommand.commit()
            hatchCommand.waitUntilCompleted()
            precondition(hatchCommand.status == .completed)
            var hatch = [UInt8](repeating: 0, count: width * height * 4)
            hatch.withUnsafeMutableBytes { hatchTexture.getBytes($0.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0) }
            return hatch
        }
        let hatch = renderHatch()
        let hatchColours = Set((0..<width * height).map { Array(hatch[$0 * 4..<$0 * 4 + 3]) })
        precondition(hatchColours.count >= 2, "Hatched background rendered a single colour")
        for (name, bytes) in [("original", original), ("shifted", shifted), ("orbited", orbited), ("reference", reference)] {
            let provider = CGDataProvider(data: Data(bytes) as CFData)!
            let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
            let url = URL(fileURLWithPath: CommandLine.arguments[4] + "/\(name).png")
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(destination, image, nil)
            precondition(CGImageDestinationFinalize(destination))
        }
        print("PASS: offscreen production Gaussian shader; mean source error", sourceError, "; camera image change", movement)
        print("PASS: orbit changes rendered view by", orbitChange, "; reset reproduces source-camera render")
        print("PASS: uncertainty marking changes sparse view by", markingChange, "; source view by", markedSourceChange,
              "; hatched background shows", hatchColours.count, "colours")
        print("PASS: GPU centres, surface-aligned footprints and source texture lookups match the CPU reference")
    }
}
