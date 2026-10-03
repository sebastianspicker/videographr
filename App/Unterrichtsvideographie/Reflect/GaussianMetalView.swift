import ExperimentalResearch
import MetalKit
import SwiftUI

struct GaussianMetalView: UIViewRepresentable {
    let surface: GaussianDepthSurface
    let sourceImage: CGImage
    let camera: GaussianCamera
    let marksUncertainty: Bool
    let onFailure: (String) -> Void

    func makeCoordinator() -> GaussianMetalRenderer { GaussianMetalRenderer() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.055, green: 0.065, blue: 0.08, alpha: 1)
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.delegate = context.coordinator
        view.accessibilityLabel = "Experimentelle Gaussian-Splat-Ansicht aus geschätzter relativer Tiefe. Schraffierte Bereiche wurden nicht aufgenommen."
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.update(surface: surface, sourceImage: sourceImage, camera: camera,
                                      marksUncertainty: marksUncertainty, view: view)
        if let failure = context.coordinator.takeUnreportedFailure() {
            // Avoid state mutation during SwiftUI's synchronous update pass.
            DispatchQueue.main.async { onFailure(failure) }
        }
    }

    static func dismantleUIView(_ view: MTKView, coordinator: GaussianMetalRenderer) {
        view.delegate = nil
        coordinator.clear()
        view.releaseDrawables()
    }
}

/// MTKView callbacks and renderer state are confined to the main actor.
/// Points and the source frame are uploaded once per scene; the vertex shader projects
/// them for each camera, so slider and drag changes only update a small uniform block.
@MainActor
final class GaussianMetalRenderer: NSObject, MTKViewDelegate {
    private struct Resources {
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        let pipeline: MTLRenderPipelineState
        let backgroundPipeline: MTLRenderPipelineState
    }

    /// Shader compilation is the slowest setup step; the pipeline holds no scene data.
    private static var sharedResources: Resources?

    private let resources: Resources?
    private(set) var failure: String?
    private var reportedFailure = false
    private var pointBuffer: MTLBuffer?
    private var orderBuffer: MTLBuffer?
    private var sourceTexture: MTLTexture?
    private var order: [UInt32] = []
    private var orderForward: SIMD3<Float>?
    private var viewUniforms = GPUView()
    private var previousSurface: GaussianDepthSurface?
    private var previousImage: CGImage?
    private var previousCamera: GaussianCamera?
    private var previousMarksUncertainty: Bool?

    var device: MTLDevice? { resources?.device }

    /// Layouts mirror the shader structs below.
    private struct GPUPoint {
        var positionOpacity: SIMD4<Float>
        /// Tangent in xyz; w is 1 beside an occlusion edge.
        var tangentU: SIMD4<Float>
        /// Tangent in xyz; w is the source-view footprint area.
        var tangentV: SIMD4<Float>
        /// Texture centre in xy, texture offset per standard deviation in zw.
        var texture: SIMD4<Float>
    }

    private struct GPUView {
        var right = SIMD4<Float>()
        var up = SIMD4<Float>()
        var forward = SIMD4<Float>()
        var position = SIMD4<Float>()
        var scale = SIMD2<Float>()
        var nearClip: Float = 0
        var maximumSigma: Float = 0
        var marksUncertainty: Float = 0
    }

    override init() {
        if let shared = Self.sharedResources {
            resources = shared
        } else if let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() {
            do {
                let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: "gaussianVertex")
                descriptor.fragmentFunction = library.makeFunction(name: "gaussianFragment")
                let attachment = descriptor.colorAttachments[0]!
                attachment.pixelFormat = .bgra8Unorm
                attachment.isBlendingEnabled = true
                attachment.sourceRGBBlendFactor = .one
                attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                attachment.sourceAlphaBlendFactor = .one
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
                // Opaque hatching marks what the camera never recorded; splats draw over it.
                let background = MTLRenderPipelineDescriptor()
                background.vertexFunction = library.makeFunction(name: "gaussianBackgroundVertex")
                background.fragmentFunction = library.makeFunction(name: "gaussianBackgroundFragment")
                background.colorAttachments[0].pixelFormat = .bgra8Unorm
                let shared = Resources(
                    device: device, commandQueue: commandQueue,
                    pipeline: try device.makeRenderPipelineState(descriptor: descriptor),
                    backgroundPipeline: try device.makeRenderPipelineState(descriptor: background)
                )
                Self.sharedResources = shared
                resources = shared
            } catch {
                resources = nil
                failure = "Die Gaussian-Splat-Darstellung konnte auf diesem Gerät nicht vorbereitet werden."
            }
        } else {
            resources = nil
            failure = "Die Perspektivansicht benötigt ein verfügbares Metal-Grafikgerät."
        }
        super.init()
    }

    /// Returns a failure once, so repeated SwiftUI updates do not repeat the report.
    func takeUnreportedFailure() -> String? {
        guard let failure, !reportedFailure else { return nil }
        reportedFailure = true
        return failure
    }

    func update(surface: GaussianDepthSurface, sourceImage: CGImage, camera: GaussianCamera,
                marksUncertainty: Bool, view: MTKView) {
        guard resources != nil, failure == nil else { return }
        let surfaceChanged = surface != previousSurface || sourceImage !== previousImage
        guard surfaceChanged || camera != previousCamera || marksUncertainty != previousMarksUncertainty else { return }
        if surfaceChanged {
            previousSurface = surface
            previousImage = sourceImage
            order = []
            orderForward = nil
            pointBuffer = makeBuffer(surface.points.map { point in
                GPUPoint(
                    positionOpacity: SIMD4(point.x, point.y, point.z, point.opacity),
                    tangentU: SIMD4(point.tangentU, point.isOcclusionEdge ? 1 : 0),
                    tangentV: SIMD4(point.tangentV, point.sourceFootprintArea),
                    texture: SIMD4(lowHalf: point.textureCenter, highHalf: point.textureStep)
                )
            })
            sourceTexture = makeTexture(sourceImage)
        }
        previousCamera = camera
        previousMarksUncertainty = marksUncertainty
        let frame = GaussianViewFrame(camera: camera)
        // Translation leaves the far-to-near order unchanged; only orientation re-sorts it.
        if frame.forward != orderForward {
            order = GaussianProjection.drawOrder(surface, forward: frame.forward, reusing: order)
            orderForward = frame.forward
            orderBuffer = makeBuffer(order)
        }
        let tangent = GaussianProjection.tangent
        viewUniforms = GPUView(
            right: SIMD4(frame.right, 0), up: SIMD4(frame.up, 0),
            forward: SIMD4(frame.forward, 0), position: SIMD4(frame.position, 1),
            scale: SIMD2(1 / (tangent * surface.aspectRatio), 1 / tangent),
            nearClip: GaussianProjection.nearClip, maximumSigma: GaussianProjection.maximumSigma,
            marksUncertainty: marksUncertainty ? 1 : 0
        )
        if !order.isEmpty, pointBuffer == nil || orderBuffer == nil || sourceTexture == nil {
            failure = "Für die Gaussian-Splat-Darstellung ist nicht genug Grafikspeicher verfügbar."
            clear()
        }
        view.setNeedsDisplay()
    }

    private func makeBuffer<Element>(_ elements: [Element]) -> MTLBuffer? {
        elements.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress, !bytes.isEmpty else { return nil }
            return resources?.device.makeBuffer(bytes: base, length: bytes.count, options: .storageModeShared)
        }
    }

    /// Splats sample the full-resolution frame, so detail is not limited to the point grid.
    /// The frame is drawn like the point colours: device RGB, non-linear 8-bit values.
    private func makeTexture(_ image: CGImage) -> MTLTexture? {
        let width = image.width, height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false
        )
        descriptor.usage = .shaderRead
        guard drawn, width > 0, height > 0, let texture = resources?.device.makeTexture(descriptor: descriptor) else { return nil }
        rgba.withUnsafeBytes { bytes in
            texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                            withBytes: bytes.baseAddress!, bytesPerRow: width * 4)
        }
        return texture
    }

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        MainActor.assumeIsolated { view.setNeedsDisplay() }
    }

    nonisolated func draw(in view: MTKView) {
        MainActor.assumeIsolated { drawOnMain(in: view) }
    }

    private func drawOnMain(in view: MTKView) {
        guard let resources, let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let command = resources.commandQueue.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }
        var period = 10 * Float(view.contentScaleFactor)
        encoder.setRenderPipelineState(resources.backgroundPipeline)
        encoder.setFragmentBytes(&period, length: MemoryLayout<Float>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.setRenderPipelineState(resources.pipeline)
        if let pointBuffer, let orderBuffer, let sourceTexture, !order.isEmpty {
            var uniforms = viewUniforms
            encoder.setVertexBuffer(pointBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(orderBuffer, offset: 0, index: 1)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<GPUView>.stride, index: 2)
            encoder.setFragmentTexture(sourceTexture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: order.count)
        }
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
    }

    func clear() {
        pointBuffer = nil
        orderBuffer = nil
        sourceTexture = nil
        order = []
        orderForward = nil
        previousSurface = nil
        previousImage = nil
        previousCamera = nil
        previousMarksUncertainty = nil
    }

    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct GaussianPoint { float4 positionOpacity; float4 tangentU; float4 tangentV; float4 texture; };
    struct GaussianView {
        float4 right; float4 up; float4 forward; float4 position;
        float2 scale; float nearClip; float maximumSigma; float marksUncertainty;
    };
    struct Raster { float4 position [[position]]; float2 local; float2 uv; half opacity; half uncertainty; };
    // Mirrors GaussianProjection.project: one camera-space projection per instance.
    vertex Raster gaussianVertex(uint vertexID [[vertex_id]], uint instanceID [[instance_id]],
                                 const device GaussianPoint* points [[buffer(0)]],
                                 const device uint* order [[buffer(1)]],
                                 constant GaussianView& view [[buffer(2)]]) {
        constexpr float2 corners[4] = { float2(-3, -3), float2(3, -3), float2(-3, 3), float2(3, 3) };
        GaussianPoint point = points[order[instanceID]];
        float3 delta = point.positionOpacity.xyz - view.position.xyz;
        float depth = dot(delta, view.forward.xyz);
        Raster out;
        out.local = corners[vertexID];
        out.uv = point.texture.xy + out.local * point.texture.zw;
        out.opacity = half(point.positionOpacity.w);
        out.uncertainty = 0.0h;
        if (!(depth > view.nearClip)) {
            // Every corner shares one clipped position, so the quad has no area.
            out.position = float4(0, 0, -1, 1);
            return out;
        }
        float2 lateral = float2(dot(delta, view.right.xyz), dot(delta, view.up.xyz));
        float2 center = lateral * view.scale / depth;
        // Surface-aligned footprint through the local perspective Jacobian. The quad is the
        // image of the ±3 sigma square, so `local` stays in standard-deviation units.
        float3 tangentU = point.tangentU.xyz, tangentV = point.tangentV.xyz;
        float2 axisU = (float2(dot(tangentU, view.right.xyz), dot(tangentU, view.up.xyz))
                        - lateral / depth * dot(tangentU, view.forward.xyz)) * view.scale / depth;
        float2 axisV = (float2(dot(tangentV, view.right.xyz), dot(tangentV, view.up.xyz))
                        - lateral / depth * dot(tangentV, view.forward.xyz)) * view.scale / depth;
        float extent = max(length(float2(axisU.y, axisV.y)),
                           length(float2(axisU.x, axisV.x)) * view.scale.y / view.scale.x);
        // Mirrors GaussianEvidence.uncertainty: displayed over recorded footprint area, from
        // the axes before the size clamp.
        float stretch = abs(axisU.x * axisV.y - axisU.y * axisV.x) / max(point.tangentV.w, 1e-12f);
        float ramp = clamp((stretch - 1.5f) / (3.0f - 1.5f), 0.0f, 1.0f);
        float uncertainty = max(ramp * ramp * (3.0f - 2.0f * ramp), point.tangentU.w > 0.5f ? 0.5f : 0.0f);
        out.uncertainty = half(isfinite(stretch) ? uncertainty : 1.0f) * half(view.marksUncertainty);
        float limit = extent > view.maximumSigma ? view.maximumSigma / extent : 1.0f;
        out.position = float4(center + (out.local.x * axisU + out.local.y * axisV) * limit, 0, 1);
        return out;
    }
    fragment half4 gaussianFragment(Raster in [[stage_in]], texture2d<half> source [[texture(0)]]) {
        constexpr sampler bilinear(filter::linear, address::clamp_to_edge);
        half alpha = in.opacity * half(exp(-0.5f * dot(in.local, in.local)));
        // Amber tint marks interpolation between recorded samples; zero leaves the colour as is.
        half3 color = mix(source.sample(bilinear, in.uv).rgb, half3(1.0h, 0.62h, 0.0h), in.uncertainty * 0.65h);
        return half4(color * alpha, alpha);
    }
    // Full-screen triangle with 45 degree stripes: hatching means the camera recorded nothing here.
    vertex float4 gaussianBackgroundVertex(uint vertexID [[vertex_id]]) {
        constexpr float2 corners[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
        return float4(corners[vertexID], 0, 1);
    }
    fragment half4 gaussianBackgroundFragment(float4 position [[position]], constant float& period [[buffer(0)]]) {
        bool stripe = fmod(position.x + position.y, period) < period * 0.35f;
        return stripe ? half4(0.36h, 0.38h, 0.42h, 1.0h) : half4(0.055h, 0.065h, 0.08h, 1.0h);
    }
    """
}
